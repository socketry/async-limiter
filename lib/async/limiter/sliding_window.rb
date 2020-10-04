require "async/clock"
require_relative "base"
require_relative "burstable"

module Async
  module Limiter
    # Ensures units are acquired during the sliding time window.
    # Example: You can perform N operations at 10:10:10.999 but can't perform
    # another N operations until 10:10:11.999.
    class SlidingWindow < Base
      include Burstable

      attr_reader :window

      def initialize(*args, window: 1, **options)
        super(*args, **options)

        @window = window
        @acquired_times = []
      end

      def blocking?
        window_blocking?
      end

      def acquire
        super

        @acquired_times.unshift(Clock.now)
        @acquired_times = @acquired_times.first(@limit)
      end

      private

      def window_blocking?
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
