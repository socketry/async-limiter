require_relative "../limiter"

module Async
  class Limiter
    # Allows running x units of work concurrently.
    # Has the same logic as Async::Semaphore.
    class Concurrent < Limiter
    end
  end
end
