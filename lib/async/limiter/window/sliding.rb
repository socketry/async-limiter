require_relative "../window"

module Async
  module Limiter
    class Window
      # Ensures units are acquired during the sliding time window.
      # Example: You can perform N operations at 10:10:10.999 but can't perform
      # another N operations until 10:10:11.999.
      class Sliding < Window
        def initialize(limit = 1, window: 1, parent: nil,
          release_required: true)
          super(
            limit,
            type: :sliding,
            burstable: true,
            window: window,
            parent: parent,
            release_required: release_required
          )
        end
      end
    end
  end
end
