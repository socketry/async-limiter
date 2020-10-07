require_relative "window"

module Async
  module Limiter
    # Ensures units are acquired during the sliding time window.
    # Example: You can perform N operations at 10:10:10.999 but can't perform
    # another N operations until 10:10:11.999.
    class SlidingWindow < Window
      private

      def window_blocking?
        @burstable && next_window_start_time > Clock.now
      end

      def next_window_start_time
        first_time_in_limit_scope + @window
      end

      def first_time_in_limit_scope
        @acquired_times.fetch(@limit - 1, NULL_TIME)
      end
    end
  end
end
