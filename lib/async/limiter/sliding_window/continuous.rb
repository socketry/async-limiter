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
      class Continuous < Base

        attr_reader :window

        def initialize(*args, window: 1, **options)
          super(*args, **options)

          @window = window
          @acquired_times = []
        end

        def blocking?
          window_limited?
        end

        def acquire
          wait
          @count += 1

          @acquired_times.unshift(Clock.now)
          @acquired_times = @acquired_times.first(@limit)
        end

        def release
          @count -= 1
        end

        private

        def window_limited?
          first_time_in_limit_scope >= window_start_time
        end

        def first_time_in_limit_scope
          @acquired_times.fetch(@limit - 1, NULL_TIME)
        end

        def window_start_time
          Clock.now - @window
        end

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

        def resume_waiting
          while !blocking? && (fiber = @waiting.shift)
            fiber.resume if fiber.alive?
          end
        end
      end
    end
  end
end
