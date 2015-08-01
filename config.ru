# STDOUT.sync = true
# STDERR.sync = true

require 'yip'

builder = Rack::Builder.new do
  use Rack::Reloader
  use Rack::Runtime
  run Yip::RackAdapter
end

run builder.to_app
