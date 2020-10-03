require "async/clock"
require_relative "../limiter"

module Async
  class Limiter
    # Ensures units are evenly acquired during the sliding time window.
    # Example: If limit is 2 you can perform one operation every 500ms. First
    # operation at 10:10:10.000, and then another one at 10:10:10.500.
    class Throttle < Limiter
      attr_reader :window

      def initialize(*args, window: 1, min_limit: 0, **options)
        super(*args, min_limit: min_limit, **options)

        @window = window
        @last_acquired_time = -1
      end

      def blocking?
        super && current_delay.positive?
      end

      def acquire
        super
        @last_acquired_time = Clock.now
      end

      def delay
        @window.to_f / @limit
      end

      private

      def current_delay
        [delay - elapsed_time, 0].max
      end

      def elapsed_time
        Clock.now - @last_acquired_time
      end
    end
  end
end
