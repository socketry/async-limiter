module Async
  module Limiter
    NULL_TIME = -1
    MAX_LIMIT = Float::INFINITY
    MIN_WINDOW_LIMIT = Float::MIN

    Error = Class.new(StandardError)
    ArgumentError = Class.new(Error)
  end
end
