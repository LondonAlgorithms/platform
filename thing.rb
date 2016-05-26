require 'docker-api'
require 'fileutils'
require 'sinatra'
require 'pry'
require 'haml'
require 'json'

get "/upload" do
  haml :upload
end

post "/upload" do
  filename = SecureRandom.hex + '.js'
  File.open('uploads/' + filename, "w") do |f|
    f.write(params['myfile'][:tempfile].read)
  end

  build_run = "builds/" + SecureRandom.hex
  Dir.mkdir(build_run)
  Dir.mkdir(build_run + "/src")
  FileUtils.cp("uploads/" + filename, build_run + "/src/" + "algo.js")
  FileUtils.cp("Dockerfile", build_run +  "/" + "Dockerfile")

  output = create_image(build_run)
  output = output.split("\n")
  output.reject! { |s| s.empty? }
  return {text: output}.to_json
end

def create_image(folder)
  img = Docker::Image.build_from_dir(folder)

  container = Docker::Container.create('Cmd' => ['npm', 'test'], 'Image' => img.id)

  output = []

  #container.tap(&:start).attach { |stream, chunk| output << {stream:stream, chunk:chunk.to_s.force_encoding("UTF-8")} }
  container.tap(&:start).attach { |stream, chunk| output << {stream:stream, chunk:chunk.to_s} }
  s = ""
  output.each { |entry| s = s + entry[:chunk] }
  s.force_encoding("UTF-8")
end
