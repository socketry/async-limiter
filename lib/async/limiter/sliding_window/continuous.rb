require_relative "../sliding_window"
require_relative "../is_continuous"
require_relative "../burstable"

module Async
  module Limiter
    # Ensures units are acquired during the sliding time window. This limiter
    # does not require a lock to be released before a new one can be acquired.
    # Example: You can perform N operations at 10:10:10.999. When next window
    # starts at 10:10:11.999 you can acquire another N locks, even if previous
    # lock(s) were not released.
    class SlidingWindow
      class Continuous < SlidingWindow
        include IsContinuous
        include Burstable

        def initialize(...)
          super(...)

          @scheduled = true
        end

        private

        def next_window_start_time
          first_time_in_limit_scope + @window
        end
      end
    end
  end
end
