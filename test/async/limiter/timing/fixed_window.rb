# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/timing/fixed_window"
require "sus/fixtures/async/scheduler_context"

describe Async::Limiter::Timing::FixedWindow do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:fixed_window) do
		subject.new(
			1.0,  # 1 second window
			Async::Limiter::Timing::Burst::Greedy,
			3     # 3 tasks per window
		)
	end
	
	it "inherits from SlidingWindow" do
		expect(fixed_window).to be_a(Async::Limiter::Timing::SlidingWindow)
	end
	
	it "has fixed window behavior" do
		# Fixed windows align to boundaries, unlike sliding windows
		# This is hard to test precisely, but we can verify it works
		expect(fixed_window.can_acquire?).to be == true
		fixed_window.acquire
		expect(fixed_window.can_acquire?).to be == true
	end
	
	it "supports all window operations" do
		expect(fixed_window).to respond_to(:can_acquire?)
		expect(fixed_window).to respond_to(:acquire)
		expect(fixed_window).to respond_to(:wait)
	end
end
