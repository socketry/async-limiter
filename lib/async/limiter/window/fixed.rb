require_relative "window"

module Async
  module Limiter
    # Ensures units are acquired during the time window.
    # Example: You can perform N operations at 10:10:10.999, and then can
    # perform another N operations at 10:10:11.000.
    class Window
      class Fixed < Window
        def initialize(limit = 1, window: 1, parent: nil,
          release_required: true)
          super(
            limit,
            type: :fixed,
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
