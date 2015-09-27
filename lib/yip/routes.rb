module Yip module Routes extend self
  extend Yis::Renderers

  def process(req, sys)
    case req[:path]
    when '/yip.js'
      js = File.read('lib/yip/views/blimp.js')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &render_js(js))
    when '/yip.css'
      css = File.read('lib/yip/views/blimp.css')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &render_css(css))
    when '/chat_window'
      html = File.read('lib/yip/views/chat_window.html')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &render_html(html))
    when '/chat_window.js'
      js = File.read('lib/yip/views/chat_window.js')
      req
        .update_in(:res, :code) { 200 }
        .update_in(:res, &render_js(js))
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
