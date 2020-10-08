require "async/clock"
require "async/task"
require_relative "constants"

module Async
  module Limiter
    class Window
      TYPES = %i[fixed sliding].freeze
      NULL_TIME = -1
      NULL_INDEX = -1

      attr_reader :count

      attr_reader :type

      attr_reader :burstable

      attr_reader :release_required

      def initialize(limit = 1, type: :fixed, window: 1, parent: nil,
        burstable: true, release_required: true)
        @count = 0
        @input_limit = @limit = limit
        @type = type
        @input_window = @window = window
        @parent = parent
        @burstable = burstable
        @release_required = release_required

        @acquired_times = []
        @waiting = []
        @scheduler_task = nil
        @scheduled = true
        @last_acquired_time = NULL_TIME

        @acquired_window_indexes = []

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

        @acquired_times.unshift(Clock.now)
        @acquired_times = @acquired_times.first(@limit)
        @last_acquired_time = Clock.now

        if fixed?
          @acquired_window_indexes.unshift(window_index)
          @acquired_window_indexes = @acquired_window_indexes.first(@limit)
        end
      end

      def release
        @count -= 1

        # We're resuming waiting fibers when lock is released.
        resume_waiting if @release_required
      end

      def limit=(new_limit)
        validate_limit!(new_limit)

        @input_limit = @limit = new_limit

        update_concurrency

        limit
      end

      private

      def limit_blocking?
        @release_required && @count >= @limit
      end

      def window_frame_blocking?
        !@burstable && next_window_frame_start_time > Clock.now
      end

      def wait
        fiber = Fiber.current

        # @waiting.any? check prevents fibers resumed via scheduler from
        # slipping in operations before other waiting fibers get resumed.
        if blocking? || @waiting.any?
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
            while @waiting.any? && !limit_blocking?
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
          !limit_blocking?
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

        window_updated
      end

      def next_window_frame_start_time
        window_frame = @window.to_f / @limit
        @last_acquired_time + window_frame
      end

      def next_acquire_time
        if @burstable
          next_window_start_time
        else
          next_window_frame_start_time
        end
      end

      def fixed?
        @type == :fixed
      end

      def sliding?
        @type == :sliding
      end

      def window_updated
        if fixed?
          @acquired_window_indexes = @acquired_times.map(&method(:window_index))
        end
      end

      def window_blocking?
        return false unless @burstable

        if fixed?
          first_index_in_limit_scope =
            @acquired_window_indexes.fetch(@limit - 1, NULL_INDEX)
          first_index_in_limit_scope == window_index
        elsif sliding?
          next_window_start_time > Clock.now
        else
          raise "invalid type #{@type}"
        end
      end

      def next_window_start_time
        if fixed?
          window_index.next * @window
        elsif sliding?
          first_time_in_limit_scope =
            @acquired_times.fetch(@limit - 1, NULL_TIME)
          first_time_in_limit_scope + @window
        else
          raise "invalid type #{@type}"
        end
      end

      def window_index(time = Clock.now)
        (time / @window).floor
      end

      def validate!
        unless TYPES.include?(@type)
          raise ArgumentError, "invalid type #{@type.inspect}"
        end

        validate_limit!
      end

      def validate_limit!(value = @input_limit)
        unless value.positive?
          raise ArgumentError, "limit must be positive number"
        end
      end
    end
  end
end
