require_relative "../window"

module Async
  module Limiter
    class Window
      # Ensures units are acquired during the time window.
      # Example: You can perform N operations at 10:10:10.999, and then can
      # perform another N operations at 10:10:11.000.
      class Fixed < Window
        def initialize(limit = 1, window: 1, parent: nil, lock: true)
          super(
            limit,
            type: :fixed,
            burstable: true,
            window: window,
            parent: parent,
            lock: lock
          )
        end
      end
    end
  end
end
