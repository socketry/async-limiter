require "async/task"
require_relative "constants"

module Async
  module Limiter
    # Allows running x units of work concurrently.
    # Has the same logic as Async::Semaphore.
    class Concurrent
      attr_reader :count

      attr_reader :limit

      def initialize(limit = 1, parent: nil,
        max_limit: Float::INFINITY, min_limit: 1)
        @count = 0
        @limit = limit
        @waiting = []
        @parent = parent
        @max_limit = max_limit
        @min_limit = min_limit

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

        if @max_limit < 1
          raise ArgumentError, "max_limit must be greater than 1"
        end

        if @min_limit < 1
          raise ArgumentError, "max_limit must be greater than 1"
        end

        if @limit.finite? && (@limit % 1).nonzero?
          raise ArgumentError, "limit must be a whole number"
        end

        unless @limit.between?(@min_limit, @max_limit)
          raise ArgumentError, "limit not between min_limit and max_limit"
        end
      end
    end
  end
end
