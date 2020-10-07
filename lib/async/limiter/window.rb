require "async/clock"
require "async/task"
require_relative "constants"
require_relative "window_options"

module Async
  module Limiter
    class Window
      prepend WindowOptions

      attr_reader :count

      attr_reader :limit

      attr_reader :waiting

      def initialize(limit = 1, parent: nil, max_limit: MAX_LIMIT, min_limit: 1)
        @count = 0
        @limit = limit
        @waiting = []
        @parent = parent
        @max_limit = max_limit
        @min_limit = min_limit

        @scheduler_task = nil
        @scheduled = false

        validate!
      end

      def blocking?
        limit_blocking?
      end

      def async(parent: (@parent || Task.current), **options)
        acquire
        parent.async(**options) do |task|
          yield task
        ensure
          release
        end
      end

      def acquire
        wait
        @count += 1
      end

      def release
        @count -= 1

        resume_waiting
      end

      def limit=(new_limit)
        @limit = if new_limit > @max_limit
          @max_limit
        elsif new_limit < @min_limit
          @min_limit
        else
          new_limit
        end
      end

      private

      def limit_blocking?
        @count >= @limit
      end

      def wait
        fiber = Fiber.current

        # @waiting.any? check prevents fibers resumed via scheduler from
        # slipping in operations before other waiting fibers get resumed.
        if blocking? || (@scheduled && @waiting.any?)
          @waiting << fiber
          schedule if schedule?
          loop do
            Task.yield # run this line at least once
            break unless blocking?
          end
        end
      rescue Exception # rubocop:disable Lint/RescueException
        @waiting.delete(fiber)
        raise
      end

      # Schedule resuming waiting tasks.
      def schedule(parent: @parent || Task.current)
        @scheduler_task ||=
          parent.async { |task|
            while @waiting.any? && !(@release_required && limit_blocking?)
              delay = delay(next_acquire_time)
              task.sleep(delay) if delay.positive?
              resume_waiting
            end

            @scheduler_task = nil
          }
      end

      def delay(time)
        [time - Async::Clock.now, 0].max
      end

      def next_acquire_time
        raise NotImplementedError
      end

      def resume_waiting
        while !blocking? && (fiber = @waiting.shift)
          fiber.resume if fiber.alive?
        end

        # Long running non-burstable tasks may end while
        # #window_frame_blocking?. Start a scheduler if one is not running.
        schedule if schedule?
      end

      def schedule?
        @scheduled &&
          @scheduler_task.nil? &&
          @waiting.any? &&
          !(@release_required && limit_blocking?)
      end

      def validate!
        if @max_limit < @min_limit
          raise ArgumentError, "max_limit is lower than min_limit"
        end

        unless @max_limit.positive?
          raise ArgumentError, "max_limit must be positive"
        end

        unless @min_limit.positive?
          raise ArgumentError, "min_limit must be positive"
        end

        unless @limit.between?(@min_limit, @max_limit)
          raise ArgumentError, "limit not between min_limit and max_limit"
        end
      end
    end
  end
end
