require "async/limiter/window/continuous"

RSpec.describe Async::Limiter::Window::Continuous do
  include_examples :non_burstable_lockful
  include_examples :non_burstable_lockless
end
