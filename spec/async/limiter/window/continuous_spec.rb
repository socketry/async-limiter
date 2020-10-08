require "async/limiter/window/continuous"

RSpec.describe Async::Limiter::Window::Continuous do
  include_examples :non_burstable_release_required
  include_examples :non_burstable_release_not_required
end
