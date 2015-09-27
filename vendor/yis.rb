require 'hamster'

def v(*args) Hamster.vector(*args) end
def h(*args) Hamster.hash(*args) end

module Yis
  module Stack extend self
    def build(processors, sys)
      lambda { |req|
        processors.reduce(req) { |req, processor| processor.process(req, sys) }
      }
    end
  end

  module RackAdapter extend self
    def build(stack)
      lambda { |env|
        req = Req.build(env)
        req = stack.call(req)
        Req.to_rack(req)
      }
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
        headers: h(content_type: rack_req.content_type),
        res: Res.build)
    end

    def to_rack(req)
      Res.to_rack(req[:res])
    end
  end

  module ReqId
    require 'securerandom'
    extend self

    def xf(req)
      Log.debug 'req-id'

      req
        .update_in(:res, :headers, 'x-request-id') { SecureRandom.uuid }
    end
  end

  module Renderers
    def self.extended(base)
      api = Module.new do
        def render_html(html)
          lambda do |res|
            Generic.process(res, 'text/html', html)
          end
        end

        def render_js(js)
          lambda do |res|
            Generic.process(res, 'text/javascript', js)
          end
        end

        def render_css(css)
          lambda do |res|
            Generic.process(res, 'text/css', css)
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

    module Assets extend self
      def process(req, sys)
        path_prefix_pattern = /^#{Regexp.escape(sys[:assets_path_prefix])}\//
        return req unless req[:path] =~ path_prefix_pattern

        js = File.read(req[:path].sub(path_prefix_pattern, ''))

        req
          .update_in(:res, :code) { 200 }
          .update_in(:res) { |res| Renderers::Generic.process(res, 'text/javascript', js) }
      end
    end
  end

  # module Router
  #   extend self

  #   def xf(req)
  #     Log.debug 'router'

  #     case req[:path]
  #     when '/' then Home.xf(req)
  #     when '/users' then Users.xf_list(req)
  #     when '/users/create' then Users.xf_create(req)
  #     when '/lottery' then Lottery.xf(req)
  #     else NotFound.xf(req)
  #     end
  #   end
  # end

  # module Home
  #   extend self
  #   require 'hiccup'

  #   def xf(req)
  #     Log.debug 'home'

  #     html = Hiccup.html(
  #       v(:html,
  #         v(:head,
  #           v(:title, 'Hello World')),
  #         v(:body,
  #           v(:header,
  #             v(:'h1.header', 'Hello World, malord!'),
  #             v(:p, { id: 'why' }, 'because we must.')))))

  #     req
  #       .update_in(:res, :code) { 200 }
  #       .update_in(:res, &xf_(HtmlUtil, html))
  #   end
  # end

  # module Users
  #   extend self
  #   require 'yisql'

  #   @@conn = Yisql::ConnMysql2.new(database: 'yip')

  #   def xf_list(req)
  #     data = if username = req[:params]['username']
  #       q = Yisql.query('lib/queries/select_users_by_username.sql')
  #       q.(@@conn, username: username)
  #     else
  #       q = Yisql.query('lib/queries/select_users.sql')
  #       q.(@@conn)
  #     end

  #     req
  #       .update_in(:res, :code) { 200 }
  #       .update_in(:res, &xf_(JsonUtil, data.to_a))
  #   end

  #   def xf_create(req)
  #     username = req[:params]['username']
  #     q = Yisql.query('lib/queries/insert_user.sql')
  #     data = q.(@@conn, username: username)

  #     req
  #       .update_in(:res, :code) { 201 }
  #       .update_in(:res, &xf_(JsonUtil, data.to_a))
  #   end
  # end

  # module Lottery
  #   extend self

  #   def xf(req)
  #     Log.debug 'lottery'

  #     req
  #       .update_in(:res, :code) { 200 }
  #       .update_in(:res, :body) { gen_nums }
  #       .update_in(:res, :headers, 'content-type') { 'text/plain' }
  #   end

  #   private

  #   def gen_nums
  #     Enumerator.new { |yielder|
  #       loop do
  #         Log.debug 'gen num'
  #         sleep 0.1
  #         yielder << "#{rand(100)}\n"
  #       end
  #     }.lazy
  #   end
  # end
end
