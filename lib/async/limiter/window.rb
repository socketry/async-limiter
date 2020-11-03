require "async/clock"
require "async/task"
require_relative "constants"

module Async
  module Limiter
    class Window
      TYPES = %i[fixed sliding].freeze
      NULL_TIME = -1

      attr_reader :count

      attr_reader :type

      attr_reader :lock

      def initialize(limit = 1, type: :fixed, window: 1, parent: nil,
        burstable: true, lock: true, queue: [])
        @count = 0
        @input_limit = @limit = limit
        @type = type
        @input_window = @window = window
        @parent = parent
        @burstable = burstable
        @lock = lock

        @waiting = queue
        @scheduler = nil

        @window_frame_start_time = NULL_TIME
        @window_start_time = NULL_TIME
        @window_count = 0

        update_concurrency
        validate!
      end

      def limit
        @input_limit
      end

      def window
        @input_window
      end

      def blocking?
        limit_blocking? || window_blocking? || window_frame_blocking?
      end

      def async(*queue_args, parent: (@parent || Task.current), **options)
        acquire(*queue_args)
        parent.async(**options) do |task|
          yield task
        ensure
          release
        end
      end

      def sync(*queue_args)
        acquire(*queue_args) do
          yield(@parent || Task.current)
        end
      end

      def acquire(*queue_args)
        wait(*queue_args)
        @count += 1

        current_time = Clock.now

        if window_changed?(current_time)
          @window_start_time =
            if @type == :sliding
              current_time
            elsif @type == :fixed
              (current_time / @window).to_i * @window
            else
              raise "invalid type #{@type}"
            end

          @window_count = 1
        else
          @window_count += 1
        end

        @window_frame_start_time = current_time

        return unless block_given?

        begin
          yield
        ensure
          release
        end
      end

      def release
        @count -= 1

        # We're resuming waiting fibers when lock is released.
        resume_waiting if @lock
      end

      def limit=(new_limit)
        validate_limit!(new_limit)
        @input_limit = @limit = new_limit

        update_concurrency
        resume_waiting
        reschedule if reschedule?

        limit
      end

      def window=(new_window)
        validate_window!(new_window)
        @input_window = @window = new_window

        update_concurrency
        resume_waiting
        reschedule if reschedule?

        window
      end

      private

      def limit_blocking?
        @lock && @count >= @limit
      end

      def window_blocking?
        return false unless @burstable
        return false if window_changed?

        @window_count >= @limit
      end

      def window_frame_blocking?
        return false if @burstable
        return false if window_frame_changed?

        true
      end

      def window_changed?(time = Clock.now)
        @window_start_time + @window <= time
      end

      def window_frame_changed?
        @window_frame_start_time + window_frame <= Clock.now
      end

      def wait(*queue_args)
        fiber = Fiber.current

        # @waiting.any? check prevents fibers resumed via scheduler from
        # slipping in operations before other waiting fibers get resumed.
        if blocking? || @waiting.any?
          @waiting.push(fiber, *queue_args) # queue_args used for custom queues
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

      def schedule?
        @scheduler.nil? &&
          @waiting.any? &&
          !limit_blocking?
      end

      # Schedule resuming waiting tasks.
      def schedule(parent: @parent || Task.current)
        @scheduler ||=
          parent.async { |task|
            task.annotate("scheduling tasks for #{self.class}.")

            while @waiting.any? && !limit_blocking?
              delay = [next_acquire_time - Async::Clock.now, 0].max
              task.sleep(delay) if delay.positive?
              resume_waiting
            end

            @scheduler = nil
          }
      end

      def reschedule?
        @scheduler &&
          @waiting.any? &&
          !limit_blocking?
      end

      def reschedule
        @scheduler.stop
        @scheduler = nil

        schedule
      end

      def resume_waiting
        while !blocking? && (fiber = @waiting.shift)
          fiber.resume if fiber.alive?
        end

        # Long running non-burstable tasks may end while
        # #window_frame_blocking?. Start a scheduler if one is not running.
        schedule if schedule?
      end

      def next_acquire_time
        if @burstable
          @window_start_time + @window # next window start time
        else
          @window_frame_start_time + window_frame # next window frame start time
        end
      end

      def window_frame
        @window.to_f / @limit
      end

      # If limit is a decimal number (e.g. 0.5) it needs to be adjusted.
      # Make @limit a whole number and adjust @window appropriately.
      def update_concurrency
        # reset @limit and @window
        @limit = @input_limit
        @window = @input_window

        return if @input_limit.infinite?
        return if (@input_limit % 1).zero?

        # @input_limit is a decimal number
        case @input_limit
        when 0...1
          @window = @input_window / @input_limit
          @limit = 1
        when (1..)
          if @input_window >= 2
            @window = @input_window * @input_limit.floor / @input_limit
            @limit = @input_limit.floor
          else
            @window = @input_window * @input_limit.ceil / @input_limit
            @limit = @input_limit.ceil
          end
        else
          raise "invalid limit #{@input_limit}"
        end
      end

      def validate!
        unless TYPES.include?(@type)
          raise ArgumentError, "invalid type #{@type.inspect}"
        end

        validate_limit!
        validate_window!
      end

      def validate_limit!(value = @input_limit)
        unless value.positive?
          raise ArgumentError, "limit must be positive number"
        end
      end

      def validate_window!(value = @input_window)
        unless value.positive?
          raise ArgumentError, "window must be positive number"
        end
      end
    end
  end
end
