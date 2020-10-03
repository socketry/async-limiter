require_relative "../fixed_window"

module Async
  module Limiter
    # Ensures units are acquired during the time window without requiring
    # a lock to be released before a new one can be acquired.
    # Example: You can perform N operations at 10:10:10.999. When next window
    # starts at 10:10:11.999 you can acquire another N locks, even if previous
    # lock(s) were not released.
    class FixedWindow
      class Continuous < FixedWindow
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

        def next_window_start_time
          window_index.next * @window
        end
        alias_method :next_acquire_time, :next_window_start_time
      end
    end
  end
end
