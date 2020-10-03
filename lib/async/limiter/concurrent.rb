require_relative "base"

module Async
  module Limiter
    # Allows running x units of work concurrently.
    # Has the same logic as Async::Semaphore.
    class Concurrent < Base
    end
  end
end
