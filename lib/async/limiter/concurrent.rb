require "async/task"
require_relative "constants"

module Async
  module Limiter
    class Concurrent
      attr_reader :count

      attr_reader :limit

      def initialize(limit = 1, parent: nil, queue: [])
        @count = 0
        @limit = limit
        @waiting = queue
        @parent = parent

        validate!
      end

      def blocking?
        limit_blocking?
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

        return unless block_given?

        begin
          yield
        ensure
          release
        end
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

      def wait(*queue_args)
        fiber = Fiber.current

        if blocking?
          @waiting.push(fiber, *queue_args) # queue_args used for custom queues
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
