require 'bundler'
Bundler.require

def v(*args) Hamster.vector(*args) end
def h(*args) Hamster.hash(*args) end

def xf_(receiver, *args_tail)
  Proc.new do |arg_head|
    receiver.xf(*args_tail.unshift(arg_head))
  end
end

module Yip
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

  module RackAdapter
    extend self

    def call(env)
      xfers = v(ReqId, Router)
      req = xfers.reduce(Req.build(env)) { |req, xfer| xfer.xf(req) }
      Req.to_rack(req)
    end
  end

  module Req
    extend self

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

  module Router
    extend self

    def xf(req)
      Log.debug 'router'

      case req[:path]
      when '/' then Home.xf(req)
      when '/users' then Users.xf_list(req)
      when '/users/create' then Users.xf_create(req)
      when '/lottery' then Lottery.xf(req)
      else NotFound.xf(req)
      end
    end
  end

  module ContentTypeUtil
    extend self

    def xf(res, content_type, content)
      res
        .update_in(:body) { [content] }
        .update_in(:headers, 'content-type') { content_type }
        .update_in(:headers, 'content-length') { content.size.to_s }
    end
  end

  module PlaintextUtil
    extend self

    def xf(res, plaintext)
      ContentTypeUtil.xf(res, 'text/plaintext', plaintext)
    end
  end

  module HtmlUtil
    extend self

    def xf(res, html)
      ContentTypeUtil.xf(res, 'text/html', html)
    end
  end

  module JsonUtil
    extend self
    require 'json'

    def xf(res, data)
      json = ::JSON.dump(data)
      ContentTypeUtil.xf(res, 'application/json', json)
    end
  end

  module NotFound
    extend self
    require 'hiccup'

    def xf(req)
      html = Hiccup.html(
        v(:html,
          v(:body,
            v(:h1, "Not found"))))

      req
        .update_in(:res, :code) { 404 }
        .update_in(:res) { |res| ContentTypeUtil.xf(res, 'text/html', html) }
    end
  end

  module Home
    extend self
    require 'hiccup'

    def xf(req)
      Log.debug 'home'

      html = Hiccup.html(
        v(:html,
          v(:head,
            v(:title, "Hello World")),
          v(:body,
            v(:header,
              v(:'h1.header', "Hello World, malord!"),
              v(:p, { id: 'why' }, "because we must.")))))

      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &xf_(HtmlUtil, html))
    end
  end

  module Users
    extend self
    require 'yisql'

    @@conn = Yisql::ConnMysql2.new(database: 'yip')

    def xf_list(req)
      data = if username = req[:params]['username']
        q = Yisql.query('lib/queries/select_users_by_username.sql')
        q.(@@conn, username: username)
      else
        q = Yisql.query('lib/queries/select_users.sql')
        q.(@@conn)
      end

      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &xf_(JsonUtil, data.to_a))
    end

    def xf_create(req)
      username = req[:params]['username']
      q = Yisql.query('lib/queries/insert_user.sql')
      data = q.(@@conn, username: username)

      req
        .update_in(:res, :code) { 201 }
        .update_in(:res, &xf_(JsonUtil, data.to_a))
    end
  end

  module Lottery
    extend self

    def xf(req)
      Log.debug 'lottery'

      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, :body) { gen_nums }
        .update_in(:res, :headers, 'content-type') { 'text/plain' }
    end

    private

    def gen_nums
      Enumerator.new { |yielder|
        loop do
          Log.debug "gen num"
          sleep 0.1
          yielder << "#{rand(100)}\n"
        end
      }.lazy
    end
  end
end
