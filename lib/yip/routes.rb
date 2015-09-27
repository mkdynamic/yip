module Yip module Routes extend self
  extend Yis::Renderers

  def process(req, sys)
    case req[:path]
    when '/yip.js'
      js = File.read('lib/yip/resources/blimp.js')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, :headers, 'set-cookie') { |header|
          Rack::Utils.add_cookie_to_header(header, 'channel', { value: "test" })
        }
        .update_in(:res, :headers, 'set-cookie') { |header|
          Rack::Utils.add_cookie_to_header(header, 'client', { value: SecureRandom.hex(3) })
        }
        .update_in(:res, &render_js(js))
    when '/yip.css'
      css = File.read('lib/yip/resources/blimp.css')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &render_css(css))
    when '/chat_window'
      case req[:method]
      when :get
        html = File.read('lib/yip/resources/chat_window.html')
        req
          .update_in(:res, :code) { 200 }
          .update_in(:res, &render_html(html))
      when :post
        channel = req.fetch(:headers).fetch(:cookies).get('channel')
        client = req.fetch(:headers).fetch(:cookies).get('client')
        request_data = Hamster.from(JSON.load(req.fetch(:body)))
          .update_in('message', 'client') { client }
          .update_in('message', 'id') { SecureRandom.hex(16) }
        response_data = JSON.dump(ok: true)

        # sfx
        Yip::MessageBus.publish(sys[:redis], channel, { op: "create_message", data: Hamster.to_ruby(request_data) })

        req
          .update_in(:res, :code) { 200 }
          .update_in(:res, &render_json(response_data))
      end
    when '/chat_window.js'
      js = File.read('lib/yip/resources/chat_window.js')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &render_js(js))
    when '/chat_window.css'
      css = File.read('lib/yip/resources/chat_window.css')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &render_css(css))
    when '/react.js'
      js = File.read('vendor/react.js')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &render_js(js))
    when '/immutable.js'
      js = File.read('vendor/immutable.js')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &render_js(js))
    else req
    end
  end
end end
