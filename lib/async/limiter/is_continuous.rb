module Async
  module Limiter
    module IsContinuous
      def blocking?
        window_limited?
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
            delay = self.delay
            task.sleep(delay) if delay.positive?
            resume_waiting
          end
          @scheduler_task = nil
        end
      end

      def delay
        [next_acquire_time - Current.now, 0].max
      end

      def next_acquire_time
        raise NotImplementedError
      end
    end
  end
end
