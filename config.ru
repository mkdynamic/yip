STDOUT.sync = true
STDERR.sync = true

require 'nop'

builder = Rack::Builder.new do
  use Rack::Reloader, 1
  use Rack::Runtime
  run Nop::System.build[:rack_adapter]
end

run builder.to_app
