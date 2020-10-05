require "async/clock"
require_relative "base"
require_relative "window_options"

module Async
  module Limiter
    # Ensures units are acquired during the time window.
    # Example: You can perform N operations at 10:10:10.999, and then can
    # perform another N operations at 10:10:11.000.
    class FixedWindow < Base
      include WindowOptions

      NULL_INDEX = -1

      attr_reader :window

      def initialize(*args, window: 1, min_limit: MIN_WINDOW_LIMIT, **options)
        super(*args, min_limit: min_limit, **options)

        @window = window
        @acquired_times = []
        @acquired_window_indexes = []

        @scheduled = true
        adjust_limit
      end

      def blocking?
        super || window_blocking?
      end

      def acquire
        super

        @acquired_times.unshift(Clock.now)
        @acquired_times = @acquired_times.first(@limit)

        @acquired_window_indexes.unshift(window_index)
        @acquired_window_indexes = @acquired_window_indexes.first(@limit)
      end

      private

      def window_blocking?
        first_index_in_limit_scope == window_index
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
