STDOUT.sync = true
STDERR.sync = true

require 'yip'

builder = Rack::Builder.new do
  use Rack::Reloader, 1
  use Rack::Runtime
  run Yip::System.build[:rack_adapter]
end

run builder.to_app
