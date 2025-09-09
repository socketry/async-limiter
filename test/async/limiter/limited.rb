# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/limited"
require "async/limiter/timing/fixed_window"
require "async/limiter/timing/leaky_bucket"
require "sus/fixtures/async/scheduler_context"

describe Async::Limiter::Limited do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:semaphore) {Async::Limiter::Limited.new(2)}
	
	it "enforces the limit" do
		expect(semaphore.limit).to be == 2
		expect(semaphore.can_acquire?).to be == true
	end
	
	it "blocks when at limit" do
		semaphore.acquire
		semaphore.acquire
		expect(semaphore.can_acquire?).to be == false
		expect(semaphore.acquire(timeout: 0)).to be == nil
	end
	
	it "waits for capacity" do
		semaphore.acquire
		semaphore.acquire
		
		# This task will wait for capacity:
		thread = Thread.new do
			semaphore.acquire(timeout: 0.01)
		end
		
		expect(thread.value).to be == nil
	end
	
	it "releases correctly" do
		semaphore.acquire
		semaphore.release
		expect(semaphore.can_acquire?).to be == true
	end
	
	it "supports non-blocking acquire" do
		expect(semaphore.acquire(timeout: 0)).to be == true
		expect(semaphore.acquire(timeout: 0)).to be == true
		expect(semaphore.acquire(timeout: 0)).to be == nil  # At limit
	end
	
	it "supports non-blocking acquire with block" do
		result = nil
		result_value = semaphore.acquire(timeout: 0) do
			result = "executed"
		end
		expect(result_value).to be == "executed"
		expect(result).to be == "executed"
		expect(semaphore.can_acquire?).to be == true  # Auto-released
	end
	
	it "supports dynamic limit adjustment" do
		expect(semaphore.limit).to be == 2
		
		semaphore.limit = 5
		expect(semaphore.limit).to be == 5
		
		expect do
			semaphore.limit = 0
		end.to raise_exception(ArgumentError)
		expect do
			semaphore.limit = -1
		end.to raise_exception(ArgumentError)
	end
	
	it "supports timeout parameter" do
		# Fill the semaphore to capacity
		semaphore.acquire  # 1/2
		semaphore.acquire  # 2/2
		
		# Non-blocking should fail when at capacity
		expect(semaphore.acquire(timeout: 0)).to be == nil
		
		# Release one resource
		semaphore.release
		
		# Non-blocking should now succeed
		expect(semaphore.acquire(timeout: 0)).to be == true
	end
	
	it "handles deadline timeouts during condition variable waits" do
		# Fill semaphore to capacity
		semaphore.acquire  # 1/2
		semaphore.acquire  # 2/2
		
		# Try to acquire with very short deadline - should timeout
		start_time = Time.now
		result = semaphore.acquire(timeout: 0.01)  # 10ms deadline
		elapsed = Time.now - start_time
		
		expect(result).to be == nil     # Should timeout
		expect(elapsed).to be < 0.1     # Should fail quickly
		expect(elapsed).to be >= 0.005  # But should have tried for some time
	end
	
	it "handles deadline expiry during condition variable waits" do
		# Fill semaphore to capacity
		semaphore.acquire  # 1/2  
		semaphore.acquire  # 2/2
		
		deadline_expired = false
		
		# Start a task that will block and timeout
		blocking_task = reactor.async do
			start_time = Time.now
			result = semaphore.acquire(timeout: 0.1)  # 100ms deadline
			elapsed = Time.now - start_time
			
			deadline_expired = true
			[result, elapsed]
		end
		
		# Wait for task to complete
		result, elapsed = blocking_task.wait
		
		# Should have timed out
		expect(deadline_expired).to be == true
		expect(result).to be == nil
		expect(elapsed).to be >= 0.05   # Should have waited some time
		expect(elapsed).to be <= 0.2    # But not too long
	end
	
	it "handles condition variable timeout edge case" do
		# This test specifically targets the @condition.wait timeout case
		# Fill semaphore to capacity
		semaphore.acquire  # 1/2
		semaphore.acquire  # 2/2
		
		# Start an async task that will actually block on condition variable
		timeout_task = reactor.async do
			# Use a longer timeout that will actually trigger @condition.wait timeout
			semaphore.acquire(timeout: 0.05)  # 50ms timeout
		end
		
		# Wait for the task to complete
		result = timeout_task.wait
		
		# Should return nil due to condition variable timeout
		expect(result).to be == nil
	end
	
	it "validates cost against timing strategy capacity" do
		# Create limiter with LeakyBucket (capacity: 3)
		timing = Async::Limiter::Timing::LeakyBucket.new(1.0, 3.0)
		cost_limiter = Async::Limiter::Limited.new(10, timing: timing)
		
		# Normal costs should work
		expect(cost_limiter.acquire(cost: 1.0)).to be == true
		expect(cost_limiter.acquire(cost: 3.0)).to be == true
		
		# Cost exceeding capacity should raise error
		expect do
			cost_limiter.acquire(cost: 3.1)
		end.to raise_exception(ArgumentError)
		
		expect do
			cost_limiter.acquire(cost: 10.0)
		end.to raise_exception(ArgumentError)
	end
	
	it "validates even small costs against tiny capacity" do
		# Create limiter with very small capacity
		timing = Async::Limiter::Timing::LeakyBucket.new(1.0, 0.5)  # Capacity 0.5
		tiny_limiter = Async::Limiter::Limited.new(10, timing: timing)
		
		# Even cost: 1 should be rejected
		expect do
			tiny_limiter.acquire(cost: 1.0)
		end.to raise_exception(ArgumentError)
		
		# Only very small costs should work
		expect(tiny_limiter.acquire(cost: 0.3)).to be == true
		expect(tiny_limiter.acquire(cost: 0.5)).to be == true
	end
	
	with "timing coordination" do
		let(:timing) {Async::Limiter::Timing::FixedWindow.new(1.0, Async::Limiter::Timing::BurstStrategy::Greedy, 2)}
		
		# High concurrency limit, low timing limit:
		let(:semaphore) {Async::Limiter::Limited.new(10, timing: timing)}
		
		it "prevents timing limit violations under concurrent access" do
			results = []
			
			# Start many concurrent acquire operations
			tasks = 10.times.map do |i|
				reactor.async do
					if semaphore.acquire(timeout: 0)
						results << i
						semaphore.release
					end
				end
			end
			
			tasks.each(&:wait)
			
			# Should only allow 2 acquisitions due to timing limit
			expect(results.size).to be <= 2
		end
		
		it "maintains timing limits even with rapid concurrent attempts" do
			successful_acquisitions = 0
			
			# Rapid concurrent attempts
			tasks = 20.times.map do
				reactor.async do
					if semaphore.acquire(timeout: 0)
						successful_acquisitions += 1
						semaphore.release
					end
				end
			end
			
			tasks.each(&:wait)
			
			# Timing limit should be enforced
			expect(successful_acquisitions).to be <= 2
		end
		
		it "prevents convoy effect - quick timeouts not blocked by slow timeouts" do
			# Create a limiter that will block (timing constraint)
			timing = Async::Limiter::Timing::LeakyBucket.new(0.1, 1, initial_level: 1.0)
			convoy_limiter = Async::Limiter::Limited.new(1, timing: timing)
			
			# Fill the limiter to capacity
			convoy_limiter.acquire  # This will succeed but fill timing capacity
			
			quick_task_times = []
			slow_task_started = false
			
			# Start a task with long timeout that will block
			slow_task = reactor.async do
				slow_task_started = true
				start_time = Time.now
				result = convoy_limiter.acquire(timeout: 1.0)  # Long timeout
				end_time = Time.now
				[:slow, result, end_time - start_time]
			end
			
			# Wait for slow task to start and enter wait state
			sleep(0.01) until slow_task_started
			sleep(0.01) # Give it time to enter wait
			
			# Start quick tasks that should not be blocked by the slow task
			quick_tasks = 3.times.map do |i|
				reactor.async do
					start_time = Time.now
					result = convoy_limiter.acquire(timeout: 0)  # Non-blocking
					end_time = Time.now
					quick_task_times << end_time - start_time
					[:quick, i, result, end_time - start_time]
				end
			end
			
			# Wait for quick tasks to complete (they should be fast)
			quick_results = quick_tasks.map(&:wait)
			
			# Clean up slow task
			slow_task.stop
			
			# Verify quick tasks completed quickly (not blocked by slow task)
			max_quick_time = quick_task_times.max
			expect(max_quick_time).to be < 0.1  # Should complete in less than 100ms
			
			# Verify quick tasks got expected results (nil since at capacity)
			quick_results.each do |result|
				expect(result[2]).to be == nil  # timeout: 0 should return nil when blocked
			end
		end
	end
end
