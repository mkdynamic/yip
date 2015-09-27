require 'bundler/setup'
require 'yis'

require 'tubesock'
require 'securerandom'
require 'redis'
require 'json'

Thread.abort_on_exception = true

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
  require 'yip/message_bus'

  def build
    processors = v(Routes,
      Yis::Processors::NotFound)

    sys = h(assets_path_prefix: '/assets',
      redis: Redis.new)
    stack = Yis::Stack.build(processors, sys)
    rack_adapter = Yis::RackAdapter.build(stack)

    rack_adapter_ws_wrap = lambda do |env|
      if env['HTTP_UPGRADE'] == 'websocket'
        redis_in = Redis.new
        redis_out = sys[:redis]
        socket_id = SecureRandom.hex(16)
        tubesock = Tubesock.hijack(env)
        tubesock.onopen do
          puts "ws open #{socket_id}"
        end
        tubesock.onmessage do |msg|
          puts "ws message #{socket_id} #{msg}"
          Yip::MessageBus.publish(redis_out, socket_id, JSON.load(msg))
        end
        tubesock.onclose do
          puts "ws close #{socket_id}"
          Yip::MessageBus.unsubscribe(redis_in, socket_id)
          redis_in.disconnect
        end
        Thread.new do
          Yip::MessageBus.subscribe(redis_in, socket_id) do |message|
            tubesock.send_data(JSON.dump(message))
          end
        end
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
