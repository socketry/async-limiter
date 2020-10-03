module Async
  module Limiter
    module IsContinuous
      def blocking?
        window_limited? || window_frame_limited?
      end

      def release
        @count -= 1
      end

      private

      def wait
        fiber = Fiber.current

        # @waiting.any? check prevents resumed fibers from slipping in
        # operations before other waiting fibers got resumed.
        if blocking? || @waiting.any?
          @waiting << fiber
          @scheduler_task ||= schedule
          loop do
            Task.yield
            break unless blocking?
          end
        end
      rescue Exception # rubocop:disable Lint/RescueException
        @waiting.delete(fiber)
        raise
      end

      def schedule(parent: @parent || Task.current)
        parent.async do |task|
          while @waiting.any?
            delay = delay(next_acquire_time)
            task.sleep(delay) if delay.positive?
            resume_waiting
          end
          @scheduler_task = nil
        end
      end

      def delay(time)
        [time - Current.now, 0].max
      end

      def next_acquire_time
        @burstable ? next_window_start_time : next_window_frame_start_time
      end
    end
  end
end
