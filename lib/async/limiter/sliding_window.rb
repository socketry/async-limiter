require "async/clock"
require_relative "base"

module Async
  module Limiter
    # Ensures units are acquired during the sliding time window.
    # Example: You can perform N operations at 10:10:10.999 but can't perform
    # another N operations until 10:10:11.999.
    class SlidingWindow < Base
      NULL_TIME = -1
      attr_reader :window

      attr_reader :burstable

      def initialize(*args, window: 1, burstable: true,
        min_limit: 0, **options)
        super(*args, min_limit: min_limit, **options)

        @window = window
        @burstable = burstable
        @acquired_times = []
      end

      def blocking?
        super && window_limited? && (@burstable || current_delay.positive?)
      end

      def acquire
        super
        @acquired_times.unshift(Clock.now)
        @acquired_times = @acquired_times.first(@limit)
        @last_acquired_time = NULL_TIME
      end

      private

      def current_delay
        [delay - elapsed_time, 0].max
      end

      def delay
        @window.to_f / @limit
      end

      def elapsed_time
        Clock.now - @last_acquired_time
      end

      def window_limited?
        first_time_in_limit_scope >= window_start_time
      end

      def first_time_in_limit_scope
        @acquired_times.fetch(@limit - 1, NULL_TIME)
      end

      def window_start_time
        Clock.now - @window
      end
    end
  end
end
