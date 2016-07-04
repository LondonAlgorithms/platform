require "docker-api"
require "net/http"
require "fileutils"
require "sinatra"
require "pry"
require "haml"
require "json"
require './app/image_runner_service'

set :bind, "0.0.0.0"
configure { set :server, :puma }

post "/submit" do
  content_type :json
  response['Access-Control-Allow-Origin'] = "*"

  params = JSON.parse(request.body.read)
  output = ImageRunnerService.new(params).run

  {"output": output}.to_json
end
