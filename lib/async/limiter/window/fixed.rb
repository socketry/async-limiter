require_relative "../window"

module Async
  module Limiter
    class Window
      class Fixed < Window
        def initialize(limit = 1, window: 1, parent: nil, lock: true, queue: [])
          super(
            limit,
            type: :fixed,
            burstable: true,
            window: window,
            parent: parent,
            lock: lock,
            queue: queue
          )
        end
      end
    end
  end
end
