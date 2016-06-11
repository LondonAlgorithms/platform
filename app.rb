require "docker-api"
require "net/http"
require "fileutils"
require "sinatra"
require "pry"
require "haml"
require "json"

set :bind, "0.0.0.0"
INTEGRITY_APP_URL = "http://localhost:4444/"

get "/pathfinding" do
  erb :pathfinding
end

post "/upload" do
  problem = params["problem"] || "greedy"
  language = params["language"].downcase || "javascript"
  docker_image = problem + "-" + language
  build_run = "builds/" + docker_image + "-" + SecureRandom.hex
  Dir.mkdir(build_run)

  hash = { "javascript" => "js", "ruby" => "rb" }

  File.open("#{build_run}/algo.#{hash[language]}", "w") do |f|
    f.write(params["myfile"][:tempfile].read)
  end

  fetch_spec_file_and_dockerfile(docker_image, build_run)

  output = create_image(build_run).split("\n").reject(&:empty?)
  erb :output, :locals => {"output": output}
end

def request_url(url)
  url = URI.parse(url)
  req = Net::HTTP::Get.new(url.to_s)
  res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }
  res.body
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
