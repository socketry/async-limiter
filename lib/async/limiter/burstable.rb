module Async
  module Limiter
    module Burstable
      attr_reader :burstable

      def initialize(*args, burstable: true, **options)
        super(*args, **options)

        @burstable = burstable
        @last_acquired_time = NULL_TIME
      end

      def blocking?
        super && (@burstable || current_delay.positive?)
      end

      def acquire
        super

        @last_acquired_time = Clock.now
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
    end
  end
end
