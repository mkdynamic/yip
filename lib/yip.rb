require 'bundler/setup'
require 'yis'

require 'tubesock'

# XXX * https://github.com/ngauthier/tubesock/issues/32
Tubesock.class_eval do
  private

  def each_frame
    framebuffer = WebSocket::Frame::Incoming::Server.new(version: @version)

    # XXX *
    io = @socket.instance_variable_get(:@io)

    while IO.select([io])
      if io.respond_to?(:recvfrom)
        data, addrinfo = io.recvfrom(2000)
      else
        data, addrinfo = io.readpartial(2000), io.peeraddr
      end
      break if data.empty?
      framebuffer << data
      while frame = framebuffer.next
        case frame.type
        when :close
          return
        when :text, :binary
          yield frame.data
        end
      end
    end
  rescue Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Errno::ECONNRESET, IOError, Errno::EBADF
    nil # client disconnected or timed out
  end
end

module Yip module System extend self
  require 'yip/routes'

  def build
    processors = v(Routes,
      Yis::Processors::NotFound)

    sys = h(assets_path_prefix: '/assets')
    stack = Yis::Stack.build(processors, sys)
    rack_adapter = Yis::RackAdapter.build(stack)

    rack_adapter_ws_wrap = lambda do |env|
      if env['HTTP_UPGRADE'] == 'websocket'
        tubesock = Tubesock.hijack(env)
        tubesock.onopen { puts "ws open" }
        tubesock.onmessage { |msg| puts "ws message #{msg}" }
        tubesock.onclose { "ws close" }
        tubesock.listen
        [200, {}, []] # 200 is just to keep lint happy, not actually sent to client
      else
        rack_adapter.call(env)
      end
    end

    h(stack: stack,
      rack_adapter: rack_adapter_ws_wrap)
  end
end end
