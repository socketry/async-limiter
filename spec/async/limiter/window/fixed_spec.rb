require "async/limiter/window/fixed"

RSpec.describe Async::Limiter::Window::Fixed do
  include_examples :burstable_lockful
  include_examples :burstable_lockless
end
