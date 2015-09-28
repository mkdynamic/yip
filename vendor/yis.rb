require 'hamster'
require 'tubesock'
require 'securerandom'
require 'redis'
require 'json'
require 'rack'

def v(*args) Hamster::Vector[*args] end
def h(*args) Hamster::Hash[*args] end

# module Yip module MessageBus extend self
#   def subscribe(redis, channel_name, &blk)
#     redis.subscribe("message_bus:#{channel_name}") do |on|
#       on.message do |channel, msg|
#         blk.call(JSON.load(msg))
#       end
#     end # blocks
#   end

#   def publish(redis, channel_name, message)
#     redis.publish("message_bus:#{channel_name}", JSON.dump(message))
#   end
# end end


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


# # HTTP request
#     http_dispatch = case request.method, request.path
#     when "GET /foo/bar"
#     when "POST /foo"
#     end

#     # WS message
#     ws_dispatch = case message.channel, message.op
#     when "OPEN|CLOSE|RECEIVE|TRASMIT /chat_room_1/new_message"
#     end

module Yis
  module Stack extend self
    def build(processors, sys)
      lambda { |com|
        processors.reduce(com) { |com, processor| processor.process(com, sys) }
      }
    end
  end

  module RackAdapter extend self
    def build(stack_http: nil, stack_web_socket: nil)
      lambda do |env|
        if env['HTTP_UPGRADE'] == 'websocket'
          sck = Tubesock.hijack(env)
          sck.define_singleton_method(:sck_id) { SecureRandom.hex(8) }
          sck.onopen {
            msg = WebSocket::Msg.build(sck: sck, type: :connect, env: env)
            msg = stack_web_socket.call(msg)
            WebSocket::Outbox.dispatch(stack_web_socket, msg[:outbox]) }
          sck.onmessage { |raw|
            msg = WebSocket::Msg.build(sck: sck, type: :receive, raw: raw)
            msg = stack_web_socket.call(msg)
            WebSocket::Outbox.dispatch(stack_web_socket, msg[:outbox]) }
          sck.onclose {
            msg = WebSocket::Msg.build(sck: sck, type: :disconnect)
            msg = stack_web_socket.call(msg)
            WebSocket::Outbox.dispatch(stack_web_socket, msg[:outbox]) }
          sck.listen
          [200, {}, []] # 200 is just to keep lint happy, not actually sent to client
        else
          req = Http::Req.build(env)
          req = stack_http.call(req)
          WebSocket::Outbox.dispatch(stack_web_socket, req[:outbox])
          Http::Req.to_rack(req)
        end
      end
    end
  end

  module Log
    require 'logger'

    class << self
      @@logger = Logger.new(STDOUT)
      @@logger.level = Logger::DEBUG
      @@logger.formatter = lambda { |severity, _, _, message| "#{severity.ljust(5)} #{message}\n" }

      v(:debug, :info, :warn, :error, :fatal).each do |level|
        define_method level do |message|
          @@logger.send(level, message)
        end
      end
    end
  end

  module WebSocket
    module Msg extend self
      def build(attrs = {})
        h(attrs.merge(outbox: v))
      end
    end

    module Outbox extend self
      def dispatch(stack_web_socket, msgs)
        msgs.each { |msg_out| stack_web_socket.call(msg_out) }
      end
    end

    module RouteMatchers
      def self.extended(base)
        api = Module.new do
          def m(*args)
            Matcher.new(*args)
          end
        end

        base.extend(api)
      end

      class Matcher
        def initialize(type)
          @type = type
        end

        def ===(msg)
          msg[:type] == @type
        end
      end
    end

    module Processors
      module Channel extend self
        extend Yis::WebSocket::RouteMatchers

        def process(msg, sys)
          case msg
          when m(:connect)
            msg_join = msg
              .update_in(:type) { :join }
              .update_in(:channel) { "socket-#{msg[:sck].sck_id}" }

            msg
              .update_in(:outbox) { |msgs| msgs.push(msg_join) }
          when m(:disconnect)
            msg_leave = msg
              .update_in(:type) { :leave }
              .update_in(:channel) { "socket-#{msg[:sck].sck_id}" }

            msg
              .update_in(:outbox) { |msgs| msgs.push(msg_leave) }
          else msg
          end
        end
      end
    end
  end

  module Http
    module Req extend self
      require 'rack'

      module Res
        extend self

        def build
          h(code: nil,
            headers: h,
            body: v)
        end

        def to_rack(res)
          v(res[:code],
            res[:headers].to_hash,
            res[:body]).to_a
        end
      end

      def build(rack_env)
        rack_req = Rack::Request.new(rack_env)

        h(params: h(rack_req.params),
          path: rack_req.path,
          method: rack_req.request_method.downcase.to_sym,
          headers: h(content_type: rack_req.content_type, cookies: h(rack_req.cookies)),
          res: Res.build,
          body: rack_req.body,
          outbox: v)
      end

      def to_rack(req)
        Res.to_rack(req[:res])
      end
    end

    module RouteMatchers
      def self.extended(base)
        api = Module.new do
          def m(*args)
            Matcher.new(*args)
          end
        end

        base.extend(api)
      end

      class Matcher
        def initialize(method, path)
          @method = method
          @path = path
        end

        def ===(req)
          req[:method] == @method &&
          (@path.is_a?(Regexp) ? req[:path] =~ @path : req[:path] == @path)
        end
      end
    end

    module Renderers
      def self.extended(base)
        api = Module.new do
          def render_html(html)
            lambda do |res|
              Generic.process(res, 'text/html', html)
                .update_in(:code) { 200 }
            end
          end

          def render_js(js)
            lambda do |res|
              Generic.process(res, 'text/javascript', js)
                .update_in(:code) { 200 }
            end
          end

          def render_json(data)
            lambda do |res|
              Generic.process(res, 'application/json', JSON.dump(data))
                .update_in(:code) { 200 }
            end
          end

          def render_css(css)
            lambda do |res|
              Generic.process(res, 'text/css', css)
                .update_in(:code) { 200 }
            end
          end
        end

        base.extend(api)
      end

      module Generic extend self
        def process(res, content_type, content)
          res
            .update_in(:body) { [content] }
            .update_in(:headers, 'content-type') { content_type }
            .update_in(:headers, 'content-length') { content.bytesize.to_s }
        end
      end

      # module Plaintext
      #   extend self

      #   def xf(res, plaintext)
      #     Generic.xf(res, 'text/plaintext', plaintext)
      #   end
      # end

      # module Html
      #   extend self

      #   def xf(res, html)
      #     Generic.xf(res, 'text/html', html)
      #   end
      # end

      # module Json
      #   extend self
      #   require 'json'

      #   def xf(res, data)
      #     json = ::JSON.dump(data)
      #     Generic.xf(res, 'application/json', json)
      #   end
      # end
    end

    module Processors
      module NotFound extend self
        require 'hiccup'

        def process(req, sys)
          return req if req[:res][:code]

          html = Hiccup.html(
            v(:html,
              v(:body,
                v(:h1, 'Not found'))))

          req
            .update_in(:res, :code) { 404 }
            .update_in(:res) { |res| Renderers::Generic.process(res, 'text/html', html) }
        end
      end
    end
  end
end




      # js = 
      # req
      #   .update_in(:res, :code) { 200 }
      #   .update_in(:res, :headers, 'set-cookie') { |header|
      #     Rack::Utils.add_cookie_to_header(header, 'channel', { value: "test" })
      #   }
      #   .update_in(:res, :headers, 'set-cookie') { |header|
      #     Rack::Utils.add_cookie_to_header(header, 'client', { value: SecureRandom.hex(3) })
      #   }
      #   .update_in(:res, &render_js(js))
      #   
