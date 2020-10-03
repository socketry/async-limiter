require_relative "../fixed_window"
require_relative "../is_continuous"

module Async
  module Limiter
    # Ensures units are acquired during the time window without requiring
    # a lock to be released before a new one can be acquired.
    # Example: You can perform N operations at 10:10:10.999. When next window
    # starts at 10:10:11.999 you can acquire another N locks, even if previous
    # lock(s) were not released.
    class FixedWindow
      class Continuous < FixedWindow
        include IsContinuous

        private

        def next_window_start_time
          window_index.next * @window
        end
        alias_method :next_acquire_time, :next_window_start_time
      end
    end
  end
end
