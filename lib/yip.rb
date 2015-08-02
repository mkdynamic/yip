require 'bundler'
Bundler.require

def v(*args) Hamster.vector(*args) end
def h(*args) Hamster.hash(*args) end

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
    def self.call(env)
      xfers = v(ReqId, Router)
      req = Req.build(env)
      res = xfers.reduce(Res.build) { |res, xfer| xfer.xf(req, res) }
      Res.to_rack(res)
    end
  end

  module Req
    def self.build(rack_env)
      rack_req = Rack::Request.new(rack_env)

      h(params: h(rack_req.params),
        path: rack_req.path,
        headers: h(content_type: rack_req.content_type))
    end
  end

  module Res
    def self.build
      h(code: nil,
        headers: h,
        body: v)
    end

    def self.to_rack(res)
      v(res[:code],
        res[:headers].to_hash,
        res[:body]).to_a
    end
  end

  module ReqId
    require 'securerandom'

    def self.xf(req, res)
      Log.debug 'req-id'

      res
        .update_in(:headers, 'x-request-id') { SecureRandom.uuid }
    end
  end

  module Router
    def self.xf(req, res)
      Log.debug 'router'

      case req[:path]
      when '/' then Home.xf(req, res)
      when '/lottery' then Lottery.xf(req, res)
      else req
      end
    end
  end

  module Home
    require 'hiccup'

    def self.xf(req, res)
      Log.debug 'home'

      body = Hiccup.html(
        v(:html,
          v(:head,
            v(:title, "Hello World")),
          v(:body,
            v(:header,
              v(:'h1.header', "Hello World!"),
              v(:p, { id: 'why' }, "because we must.")))))

      res
        .update_in(:code) { 200 }
        .update_in(:body) { [body] }
        .update_in(:headers, 'content-type') { 'text/html' }
        .update_in(:headers, 'content-length') { body.size.to_s }
    end
  end

  module Lottery
    def self.xf(req, res)
      Log.debug 'lottery'

      res
        .update_in(:code) { 200 }
        .update_in(:body) { gen_nums }
        .update_in(:headers, 'content-type') { 'text/plain' }
    end

    def self.gen_nums
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
