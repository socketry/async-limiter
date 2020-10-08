require "async/limiter/window/sliding"

RSpec.describe Async::Limiter::Window::Sliding do
  include_examples :burstable_release_required
  include_examples :burstable_release_not_required
  # include_examples :non_burstable_release_required
  # include_examples :non_burstable_release_not_required
end
