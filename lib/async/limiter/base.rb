require "async/task"

module Async
  module Limiter
    class Base
      Error = Class.new(StandardError)
      ArgumentError = Class.new(Error)

      MAX_LIMIT = Float::INFINITY
      MIN_LIMIT = Float::MIN

      attr_reader :count

      attr_reader :limit

      attr_reader :waiting

      def initialize(limit = 1, parent: nil,
        max_limit: MAX_LIMIT, min_limit: MIN_LIMIT)
        @count = 0
        @limit = limit
        @waiting = []
        @parent = parent
        @max_limit = max_limit
        @min_limit = min_limit

        validate!
      end

      def blocking?
        @count >= @limit
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

      def increase_limit(number = 1)
        new_limit = @limit + number
        return false if new_limit > @max_limit

        @limit = new_limit
      end

      def decrease_limit(number = 1)
        new_limit = @limit - number
        return false if new_limit < @min_limit

        @limit = new_limit
      end

      private

      def wait
        fiber = Fiber.current

        if blocking?
          @waiting << fiber
          Task.yield while blocking?
        end
      rescue Exception # rubocop:disable Lint/RescueException
        @waiting.delete(fiber)
        raise
      end

      def resume_waiting
        while !blocking? && (fiber = @waiting.shift)
          fiber.resume if fiber.alive?
        end
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
