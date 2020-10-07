require_relative "window"

module Async
  module Limiter
    # Ensures units are acquired during the time window.
    # Example: You can perform N operations at 10:10:10.999, and then can
    # perform another N operations at 10:10:11.000.
    class FixedWindow < Window
      NULL_INDEX = -1

      def initialize(...)
        super(...)

        @acquired_window_indexes = []
      end

      def acquire
        super

        @acquired_window_indexes.unshift(window_index)
        @acquired_window_indexes = @acquired_window_indexes.first(@limit)
      end

      private

      def window_blocking?
        @burstable && first_index_in_limit_scope == window_index
      end

      def first_index_in_limit_scope
        @acquired_window_indexes.fetch(@limit - 1, NULL_INDEX)
      end

      def window_index(time = Clock.now)
        (time / @window).floor
      end

      def next_window_start_time
        window_index.next * @window
      end

      def window_updated
        @acquired_window_indexes = @acquired_times.map(&method(:window_index))
      end
    end
  end
end
