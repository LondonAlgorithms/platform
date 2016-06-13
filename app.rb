require "docker-api"
require "net/http"
require "fileutils"
require "sinatra"
require "pry"
require "haml"
require "json"
require './image_runner_service'

set :bind, "0.0.0.0"

get "/pathfinding" do
  erb :pathfinding
end

post "/submit" do
  content_type :json
  response['Access-Control-Allow-Origin'] = "*"

  params = JSON.parse(request.body.read)
  output = ImageRunnerService.new(params).run

  {"output": output}.to_json
end

post "/upload" do
  params["text"]= params["myfile"][:tempfile].read

  output = ImageRunnerService.new(params).run

  erb :output, :locals => {"output": output}
end
