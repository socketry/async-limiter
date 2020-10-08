require "async/task"
require_relative "constants"

module Async
  module Limiter
    # Allows running x units of work concurrently.
    # Has the same logic as Async::Semaphore.
    class Concurrent
      attr_reader :count

      attr_reader :limit

      def initialize(limit = 1, parent: nil)
        @count = 0
        @limit = limit
        @waiting = []
        @parent = parent

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
        validate_limit!(new_limit)

        @limit = new_limit
      end

      private

      def limit_blocking?
        @count >= @limit
      end

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
        if @limit.finite? && (@limit % 1).nonzero?
          raise ArgumentError, "limit must be a whole number"
        end

        validate_limit!
      end

      def validate_limit!(value = @limit)
        raise ArgumentError, "limit must be greater than 1" if value < 1
      end
    end
  end
end
