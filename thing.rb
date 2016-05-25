require 'docker-api'
require 'fileutils'
require 'sinatra'
require 'haml'
require 'json'

# Handle GET-request (Show the upload form)
get "/upload" do
  haml :upload
end

# Handle POST-request (Receive and save the uploaded file)
post "/upload" do
  filename = SecureRandom.hex + '.js'
  File.open('uploads/' + filename, "w") do |f|
    f.write(params['myfile'][:tempfile].read)
  end

  build_run = SecureRandom.hex
  Dir.mkdir(build_run)
  Dir.mkdir(build_run + "/src")
  FileUtils.cp("uploads/" + filename, build_run + "/src/" + "algo.js")
  FileUtils.cp("Dockerfile", build_run +  "/" + "Dockerfile")

  output = create_image(build_run)
  return output.to_json
  #return "The file was successfully uploaded!"
end

def create_image(folder)
  puts Docker.url
  img = Docker::Image.build_from_dir(folder)
  puts img

  container = Docker::Container.create('Cmd' => ['npm', 'test'], 'Image' => img.id)

  output = []

  container.tap(&:start).attach { |stream, chunk| output << {stream:stream, chunk:chunk.to_s.force_encoding("UTF-8")} }
  output
end
