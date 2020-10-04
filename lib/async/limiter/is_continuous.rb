module Async
  module Limiter
    module IsContinuous
      def blocking?
        window_blocking? || window_frame_blocking?
      end

      def release
        @count -= 1
      end

      private

      def next_acquire_time
        @burstable ? next_window_start_time : next_window_frame_start_time
      end
    end
  end
end
