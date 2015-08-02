module Nop
  module Routes extend self
    require 'nop/routes/home'

    def process(req, sys)
      case req[:path]
      when '/' then Home.process(req, sys)
      else req
      end
    end
  end
end
