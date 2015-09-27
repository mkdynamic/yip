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
        cookies = Rack::Utils.parse_cookies(env)
        channel = cookies['channel']
        client = cookies['client']
        redis_in, redis_out = Redis.new, sys[:redis]
        socket_id = SecureRandom.hex(16)
        tubesock = Tubesock.hijack(env)
        redis_subscribe_thread = nil
        tubesock.onopen do
          puts "ws open #{socket_id} #{channel}"
        end
        tubesock.onmessage do |msg|
          puts "ws message #{socket_id} #{channel} #{msg}"
          message = Hamster.from(JSON.load(msg)).update_in('data', 'typer', 'client') { client }
          Yip::MessageBus.publish(redis_out, channel, Hamster.to_ruby(message))
        end
        tubesock.onclose do
          puts "ws closing #{socket_id} #{channel}"
          redis_subscribe_thread.kill rescue nil
          redis_in.disconnect!
          puts "ws closed #{socket_id} #{channel}"
        end
        redis_subscribe_thread = Thread.new do
          Yip::MessageBus.subscribe(redis_in, channel) do |message|
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
