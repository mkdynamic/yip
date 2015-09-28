module Yip module Routers module Http extend self
  require "yip/routers/http_chat_window"

  extend Yis::Http::RouteMatchers
  extend Yis::Http::Renderers

  def process(req, sys)
    case req
    when m(:get, "/yip.js")
      req.update_in(:res, &render_js(File.read('lib/yip/resources/blimp.js')))
    when m(:get, "/yip.css")
      req.update_in(:res, &render_css(File.read('lib/yip/resources/blimp.css')))
    when m(:get, "/chat_window")
      req.update_in(:res, &render_html(File.read('lib/yip/resources/chat_window.html')))
    when m(:post, "/chat_window")
      HttpChatWindow.process(req, sys)
    when m(:get, "/immutable.js")
      req.update_in(:res, &render_js(File.read('vendor/immutable.js')))
    when m(:get, "/react.js")
      req.update_in(:res, &render_js(File.read('vendor/react.js')))
    when m(:get, %r{.css$})
      req.update_in(:res, &render_css(File.read("lib/yip/resources#{req[:path]}")))
    when m(:get, %r{.js$})
      req.update_in(:res, &render_js(File.read("lib/yip/resources#{req[:path]}")))
    else req
    end
  end
end end end
