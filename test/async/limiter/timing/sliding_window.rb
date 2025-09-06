# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/timing/sliding_window"
require "sus/fixtures/async/scheduler_context"

describe Async::Limiter::Timing::SlidingWindow do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:window_strategy) do
		subject.new(
			1.0,  # 1 second window
			Async::Limiter::Timing::BurstStrategy::Greedy,
			2     # 2 tasks per window
		)
	end
	
	it "can be created" do
		expect(window_strategy.duration).to be == 1.0
		expect(window_strategy.limit).to be == 2
	end
	
	it "starts allowing acquisitions" do
		expect(window_strategy.can_acquire?).to be == true
	end
	
	it "tracks acquisitions" do
		expect(window_strategy.can_acquire?).to be == true
		window_strategy.acquire
		expect(window_strategy.can_acquire?).to be == true  # Still under limit
		
		window_strategy.acquire
		expect(window_strategy.can_acquire?).to be == false  # At limit
	end
	
	it "has wait method" do
		expect(window_strategy).to respond_to(:wait)
		mutex = Mutex.new
		window_strategy.wait(mutex)  # Should not hang
	end
	
	it "waits when timing constraints require it" do
		# Create a very restrictive window for testing waits
		restrictive_window = subject.new(
			0.1,  # 100ms window  
			Async::Limiter::Timing::BurstStrategy::Smooth,  # Force even distribution
			1     # Only 1 task per window
		)
		
		# Fill the window to capacity
		restrictive_window.acquire
		
		# Now timing constraints should force a wait
		expect(restrictive_window.can_acquire?).to be == false
		
		mutex = Mutex.new
		start_time = Time.now
		result = nil
		elapsed = nil
		
		# Properly synchronize around the wait call
		mutex.synchronize do
			# This should wait for the window to slide
			result = restrictive_window.wait(mutex, nil, 1)
			elapsed = Time.now - start_time
		end
		
		expect(result).to be == true
		expect(elapsed).to be > 0.05  # Should have waited for window
	end
	
	it "respects deadline during timing waits" do
		# Use the same restrictive window
		restrictive_window = subject.new(
			0.2,  # 200ms window
			Async::Limiter::Timing::BurstStrategy::Smooth,
			1     # Only 1 task per window
		)
		
		# Fill the window to capacity  
		restrictive_window.acquire
		
		# Create a very short deadline (shorter than window)
		deadline = Async::Deadline.start(0.05)  # 50ms deadline
		
		mutex = Mutex.new
		start_time = Time.now
		result = nil
		elapsed = nil
		
		# Properly synchronize around the wait call
		mutex.synchronize do
			# Should return false due to deadline expiry
			result = restrictive_window.wait(mutex, deadline, 1)
			elapsed = Time.now - start_time
		end
		
		expect(result).to be == false  # Deadline exceeded
		expect(elapsed).to be < 0.1    # Should fail quickly
	end
end
