require "async/clock"
require_relative "../limiter"

module Async
  class Limiter
    # Ensures units are acquired during the time window.
    # Example: You can perform N operations at 10:10:10.999, and then can
    # perform another N operations at 10:10:11.000.
    class FixedWindow < Limiter
      attr_reader :window

      def initialize(*args, window: 1, **options)
        super(*args, **options)

        @window = window
        @acquired_window_indexes = []
      end

      def blocking?
        super && window_limited?
      end

      def acquire
        super
        @acquired_window_indexes.unshift(window_index)
        # keep more entries in case a limit is increased
        @acquired_window_indexes = @acquired_window_indexes.first(keep_limit)
      end

      private

      def window_limited?
        first_index_in_limit_scope == window_index
      end

      def first_index_in_limit_scope
        @acquired_window_indexes.fetch(@limit - 1) { -1 }
      end

      def window_index
        (now / @window).floor
      end

      def keep_limit
        @max_limit.infinite? ? @limit * 10 : @max_limit
      end

      def now
        Clock.now
      end
    end
  end
end
