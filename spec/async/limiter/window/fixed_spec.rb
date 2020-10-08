require "async/limiter/window/fixed"

RSpec.describe Async::Limiter::Window::Fixed do
  include_examples :burstable_release_required
  include_examples :burstable_release_not_required
end
