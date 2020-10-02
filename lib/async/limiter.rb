require "async/task"

module Async
  # Base class for all the limiters.
  class Limiter
    attr_reader :count

    attr_reader :limit

    attr_reader :waiting

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
      @count >= @limit
    end

    def async(parent: (@parent or Task.current), **options)
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

      while under_limit? && (fiber = @waiting.shift)
        fiber.resume if fiber.alive?
      end
    end

    def increase_limit(number = 1)
      new_limit = @limit + number
      return false if new_limit > @max_limit

      @limit = new_limit
    end

    def decrease_limit(number = 1)
      new_limit = @limit - number
      return false if new_limit < @min_limit || !new_limit.positive?

      @limit = new_limit
    end

    def waiting_count
      @waiting.size
    end

    private

    def under_limit?
      available_units.positive?
    end

    def available_units
      @limit - @count
    end

    def wait
      fiber = Fiber.current

      if blocking?
        @waiting << fiber
        Task.yield while blocking?
      end
    rescue Exception
      @waiting.delete(fiber)
      raise
    end

    def validate!
      if max_limit < min_limit
        raise "max_limit #{@max_limit} is lower than min_limit #{@min_limit}"
      end

      raise "max_limit must be positive" unless max_limit.positive?
      raise "min_limit must be positive" unless min_limit.positive?

      unless @limit.between?(@min_limit, @max_limit)
        raise "invalid limit #{@limit}"
      end
    end
  end
end
