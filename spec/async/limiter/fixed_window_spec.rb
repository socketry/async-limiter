require "async/limiter/fixed_window"

RSpec.describe Async::Limiter::FixedWindow do
  include_examples :burstable_release_required
  include_examples :burstable_release_not_required
  include_examples :non_burstable_release_required
  include_examples :non_burstable_release_not_required
end
