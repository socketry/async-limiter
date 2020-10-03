require "async/clock"
require_relative "base"
require_relative "burstable"

module Async
  module Limiter
    # Ensures units are acquired during the sliding time window. This limiter
    # does not require a lock to be released before a new one can be acquired.
    # Example: You can perform N operations at 10:10:10.999. When next window
    # starts at 10:10:11.999 you can acquire another N locks, even if previous
    # lock(s) were not released.
    class SlidingWindow
      class Continuous < SlidingWindow

        attr_reader :window

        def blocking?
          window_limited?
        end

        def release
          @count -= 1
        end

        private

        def wait
          fiber = Fiber.current

          # waiting? prevents resumed fibers from slipping in operations
          # before other waiting fibers got resumed.
          if blocking? || waiting?
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

        def waiting?
          @waiting.any?
        end

        def schedule(parent: @parent || Task.current)
          parent.async do |task|
            while waiting?
              delay = self.delay
              task.sleep(delay) if delay.positive?
              resume_waiting
            end
            @scheduler_task = nil
          end
        end

        def delay
          next_window_start_time = first_time_in_limit_scope + @window
          [next_window_start_time - Current.now, 0].max
        end
      end
    end
  end
end
