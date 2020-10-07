require "async/limiter/sliding_window"

RSpec.describe Async::Limiter::SlidingWindow do
  include_examples :window_limiter

  include_examples :burstable_release_required
  include_examples :burstable_release_not_required
  include_examples :non_burstable_release_required
  include_examples :non_burstable_release_not_required
end
