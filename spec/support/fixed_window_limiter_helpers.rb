RSpec.shared_context :fixed_window_limiter_helpers do
  def wait_until_next_fixed_window_start
    window_index = (Async::Clock.now / limiter.window).floor
    next_window_start_time = window_index.next * limiter.window
    delay = next_window_start_time - Async::Clock.now

    Async::Task.current.sleep(delay)
  end
end
