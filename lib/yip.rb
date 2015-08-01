require 'bundler'
Bundler.require

module Yip
  module RackAdapter
    def self.call(env)
      req = Req.build(env)

      res = Res.build_404
      res = RequestId.process(req, res)
      res = Router.process(req, res)

      Res.to_rack(res)
    end
  end

  module Req
    def self.build(rack_env)
      rack_req = Rack::Request.new(rack_env)

      {
        params: rack_req.params,
        path: rack_req.path,
        headers: {
          content_type: rack_req.content_type
        }
      }
    end
  end

  module Res
    def self.build_404
      Hamster.hash(
        code: 404,
        headers: Hamster.hash('content-type' => 'text/html'),
        body: ['Not found!']
      )
    end

    def self.to_rack(res)
      [
        res[:code],
        res[:headers].to_hash,
        res[:body]
      ]
    end
  end

  module RequestId
    require 'securerandom'

    def self.process(req, res)
      puts 'request-id'

      res
        .update_in(:headers, 'x-request-id') { SecureRandom.uuid }
    end
  end

  module Router
    def self.process(req, res)
      puts 'router'

      case req[:path]
      when '/' then Home.process(req, res)
      else res
      end
    end
  end

  module Home
    require 'json'

    def self.process(req, res)
      puts 'home'

      res
        .update_in(:code) { 200 }
        .update_in(:body) { [{ title: 'Home' }.to_json] }
        .update_in(:headers, 'content-type') { 'application/json' }
    end
  end
end
