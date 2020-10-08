require_relative "../window"

module Async
  module Limiter
    class Window
      class Continuous < Window
        def initialize(limit = 1, window: 1, parent: nil,
          release_required: true)
          super(
            limit,
            type: :sliding, # type doesn't matter, but sliding is less work
            burstable: false,
            window: window,
            parent: parent,
            release_required: release_required
          )
        end
      end
    end
  end
end
