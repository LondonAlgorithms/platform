require "docker-api"
require "net/http"
require "fileutils"
require "sinatra"
require "pry"
require "haml"
require "json"

set :bind, "0.0.0.0"
INTEGRITY_APP_URL = "http://localhost:4444/"

get "/upload" do
  haml :upload
end

post "/upload" do
  content_type :json

  problem = params["problem"] || "greedy"
  language = params["language"] || "javascript"
  docker_image = problem + "-" + language
  build_run = "builds/" + docker_image + "-" + SecureRandom.hex
  Dir.mkdir(build_run)

  if language == "javascript" #-- asumme this for now
    Dir.mkdir(build_run + "/src")

    File.open("#{build_run}/src/algo.js", "w") do |f|
      f.write(params["myfile"][:tempfile].read)
    end
  end

  fetch_and_create_run_dockerfile(docker_image, build_run)

  # check if the base image exists
  if !base_image_available?(docker_image)
    # download all files and then build
    build_base_image(docker_image, build_run)
  end

  output = create_image(build_run).split("\n").reject(&:empty?)
  return {text: output}.to_json
end

def request_url(url)
  url = URI.parse(url)
  req = Net::HTTP::Get.new(url.to_s)
  res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }
  res.body
end

def base_image_available?(base_image)
  Docker::Image.exist?(base_image+":latest")
end

def build_base_image(docker_image,build_run)
  res = request_url(INTEGRITY_APP_URL + "#{docker_image}")
  files = JSON.parse(res)

  Dir.mkdir(build_run+"/" + docker_image)

  files["files"].each do |file|
    #need to add all files to build
    res = request_url(INTEGRITY_APP_URL + "#{file}")
    File.open(build_run + "/" + file, "w") do |f|
      f.write(res)
    end
  end

  Docker::Image.build_from_dir(
    build_run+"/"+docker_image,
    {
      "dockerfile" => "Dockerfile-build",
      "t" => docker_image
    }
  )
end

def fetch_and_create_run_dockerfile(docker_image, build_run)
  res = request_url(INTEGRITY_APP_URL + "#{docker_image}/Dockerfile-run")
  File.open(build_run+"/" + "Dockerfile", "w") do |f|
    f.write(res)
  end
end

def create_image(folder)
  img = Docker::Image.build_from_dir(folder)

  container = Docker::Container.create("Cmd" => ["npm", "test"], "Image" => img.id)

  output = []

  container.tap(&:start).attach { |stream, chunk| output << {stream:stream, chunk:chunk.to_s} }
  s = ""
  output.each { |entry| s = s + entry[:chunk] }
  s.force_encoding("UTF-8")
end
