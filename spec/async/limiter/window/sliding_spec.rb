require "async/limiter/window/sliding"

RSpec.describe Async::Limiter::Window::Sliding do
  include_examples :burstable_lockful
  include_examples :burstable_lockless
end
