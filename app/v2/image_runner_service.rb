require "docker-api"
require 'zlib'
require 'fileutils'

module V2
  TIMEOUT_EXECUTION = 1

  class ImageRunnerService
    def initialize(params)
      @text = params["text"]
      @language = params["language"].downcase
      @challenge = params["challenge"]
    end

    def run
      #return "Bad Input Data - Nil Params" if problem.nil? || language.nil? || text.nil?
      @docker_image = language + "-test-runner"
      @extension = SecureRandom.hex
      #time_function { p "lol" }

      create_build_run

      create_algo_file
      create_challenge_file
      res = create_image


      cleanup_build_run_dir

      res
    end

    private

    def cleanup_build_run_dir
      FileUtils.remove_dir(build_run)
      run_command(container, "rm -rf #{build_tar}")
      run_command(container, "rm -rf #{run_dir}")
    end

    def create_build_run
      @build_run = "builds/" + docker_image + "-" + extension
      Dir.mkdir(@build_run)
    end

    def create_algo_file
      filename  = filename_for_language(language)
      create_file(filename, text)
    end

    def create_challenge_file
      filename = "challenge.json"
      create_file(filename, challenge.to_json)
    end

    def create_file(filename, contents)
      File.open("#{build_run}/#{filename}", "w") do |f|
        f.write(contents)
      end
    end

    def filename_for_language(language)
      hash = { "javascript" => "js", "ruby" => "rb" }
      "algo.#{hash[language]}"
    end

    def run_command(container, command, opts = {})
      command_arr = ["bash", "-c", command]
      container.exec(command_arr, opts)
    end

    def create_image
      @container = Docker::Container.get(docker_image)
      @build_tar = "/usr/ruby-test-runner/builds/#{extension}"
      @run_dir = "/usr/ruby-test-runner/#{build_run}"

      # Send current ruby+challenge.json to the docker container
      container.archive_in("./#{build_run}/", "/usr/ruby-test-runner/builds/")
      # Create the build_dir
      run_command(container, "mkdir #{build_tar}", wait: 2)
      # Extract the files in the build dir
      run_command(container, "tar -C #{build_tar} -xvf #{run_dir}")
      # Run the ruby test interpreter
      run_command(container, "FOLDER=#{extension} ruby /usr/ruby-test-runner/app/wrapper.rb", wait: TIMEOUT_EXECUTION)
      # Capture the results of the test
      res = run_command(container, "cat #{build_tar}/output.json", tty:true, stdout: true)

      puts res
      output = JSON.parse(res[0][0])
      output
    end

    attr_reader :problem, :language, :text, :docker_image,
                :build_run, :extension, :challenge, :container, :build_tar, :run_dir
    def time_function(&block)
      before = Time.now
      yield
      after = Time.now

      puts "#{after-before} - create build run"
    end
  end
end
