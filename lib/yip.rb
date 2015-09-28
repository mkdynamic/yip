require 'bundler/setup'
require 'yis'

module Yip module System extend self
  require 'yip/routers/http'
  require 'yip/routers/web_socket'

  def build
    sys = h(
      assets_path_prefix: '/assets',
      redis: Redis.new,
      redis_web_socket: Redis.new)

    processors_http = v(
      Routers::Http,
      Yis::Http::Processors::NotFound)

    processors_web_socket = v(
      Yis::WebSocket::Processors::Channel,
      Routers::WebSocket)

    stack_http = Yis::Stack.build(processors_http, sys)
    stack_web_socket = Yis::Stack.build(processors_web_socket, sys)

    rack_adapter = Yis::RackAdapter.build(stack_http: stack_http, stack_web_socket: stack_web_socket)

    h(stack_http: stack_http,
      stack_web_socket: stack_web_socket,
      rack_adapter: rack_adapter)
  end
end end
