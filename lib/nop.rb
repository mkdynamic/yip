require 'bundler/setup'
require 'yis'

module Nop
  module System extend self
    require 'nop/routes'

    def build
      processors = v(
        Yis::Processors::Assets,
        Routes,
        Yis::Processors::NotFound
      )

      sys = { assets_path_prefix: '/assets' }
      stack = Yis::Stack.build(processors, sys)
      rack_adapter = Yis::RackAdapter.build(stack)

      h(stack: stack,
        rack_adapter: rack_adapter)
    end
  end
end
