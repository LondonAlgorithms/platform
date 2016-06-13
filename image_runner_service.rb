require "docker-api"

class ImageRunnerService
  INTEGRITY_APP_URL = "http://localhost:4444/"

  def initialize(params)
    @problem = params["problem"]
    @language = params["language"].downcase
    @text = params["text"]
  end

  def run
    return "Bad Input Data - Nil Params" if problem.nil? || language.nil? || text.nil?

    @docker_image = problem + "-" + language

    create_build_run
    create_algo_file(build_run, language, text)

    fetch_spec_file_and_dockerfile(docker_image, build_run)

    create_image(build_run)
  end

  private
  attr_reader :problem, :language, :text, :docker_image, :build_run

  def create_build_run
    @build_run = "builds/" + docker_image + "-" + SecureRandom.hex
    Dir.mkdir(@build_run)
  end

  def create_algo_file(build_run, language, text)
    filename  = filename_for_language(language)

    File.open("#{build_run}/#{filename}", "w") do |f|
      f.write(text)
    end
  end

  def filename_for_language(language)
    hash = { "javascript" => "js", "ruby" => "rb" }
    "algo.#{hash[language]}"
  end

  def fetch_spec_file_and_dockerfile(docker_image, build_run)
    res = request_url(INTEGRITY_APP_URL + "#{docker_image}")
    files = JSON.parse(res)

    Dir.mkdir(build_run+"/" + docker_image)

    files["files"].each do |file|
      res = request_url(INTEGRITY_APP_URL + "#{file}")
      File.open(build_run + "/" + file.split("/").last, "w") do |f|
        f.write(res)
      end
    end
  end

  def request_url(url)
    url = URI.parse(url)
    req = Net::HTTP::Get.new(url.to_s)
    res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }
    res.body
  end

  def create_image(folder)
    img = Docker::Image.build_from_dir(folder, {nocache: true})

    container = Docker::Container.create("Image"=>img.id)
    output = []

    container.tap(&:start).attach { |stream, chunk| output << {stream:stream, chunk:chunk.to_s} }
    s = ""
    output.each { |entry| s = s + entry[:chunk] }
    s.force_encoding("UTF-8")

    container.delete
    img.delete
    s
  end
end
