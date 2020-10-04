module Async
  module Limiter
    module Burstable
      attr_reader :burstable

      def initialize(*args, burstable: true, **options)
        super(*args, **options)

        @burstable = burstable
        @last_acquired_time = NULL_TIME
        @scheduled = !@burstable
      end

      def blocking?
        super && window_frame_blocking?
      end

      def acquire
        super

        @last_acquired_time = Clock.now
      end

      private

      def window_frame_blocking?
        @burstable || next_window_frame_start_time > Clock.now
      end

      def next_window_frame_start_time
        @last_acquired_time + window_frame
      end

      def window_frame
        @window.to_f / @limit
      end
    end
  end
end
