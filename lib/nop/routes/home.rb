module Nop module Routes module Home extend self
  extend Yis::Renderers
  require "execjs"
  # require 'java'

  # @@factory = javax.script.ScriptEngineManager.new
  # # bindings = engine.createBindings
  # @@engine = @@factory.getEngineByName('nashorn')
  # @@engine.eval("var global = this")
  # @@engine.eval("var window = {}")
  # @@engine.eval(File.read("vendor/react.js"))
  # @@engine.eval(File.read("lib/nop/routes/home.js"))


  def process(req, sys)
    # FIXME
    # html = Hiccup.html(
    #   v(:html,
    #     v(:head,
    #       v(:title, 'Home'),
    #       v(:script, h(src: '/assets/vendor/react.js')),
    #       v(:script, h(src: '/assets/lib/nop/routes/home.js'))),
    #     v(:body,
    #       v(:div, h(id: 'react-root')),
    #       v(:script, "React.render(React.createElement(Hello), document.getElementById('react-root'))"))))


  source = []
  source << "var global = this"
  source << "var window = {}"
  source << File.read("vendor/react.js")
  source << File.read("lib/nop/routes/home.js")
  engine = ExecJS.compile(source.join(";"))

    preloaded = engine.eval <<-JS
      window.React.renderToString(
        window.React.createElement(window.Hello)
      )
    JS

    html = <<-HTML
      <html>
        <head>
          <title>Home</title>
          <script src="/assets/vendor/react.js"></script>
          <script src="/assets/lib/nop/routes/home.js"></script>
        </head>
        <body>
          <div id="react-root">#{preloaded}</div>
          <script>
            var boot = function() {
              React.render(
                React.createElement(Hello),
                document.getElementById('react-root')
              );
            };

            window.setTimeout(boot, 5000);
          </script>
        </body>
      </html>
    HTML

    req
      .update_in(:res, :code) { 200 }
      .update_in(:res, &render_html(html))
  end
end end end

# factory = javax.script.ScriptEngineManager.new
# engine = factory.getEngineByName 'nashorn'
# bindings = engine.createBindings
# engine.eval javascript_code, bindings
