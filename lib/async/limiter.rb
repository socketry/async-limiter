require_relative "limiter/concurrent"
require_relative "limiter/delay"
require_relative "limiter/fixed_window"
require_relative "limiter/sliding_window"

module Async
  module Limiter
    NULL_TIME = -1
  end
end
