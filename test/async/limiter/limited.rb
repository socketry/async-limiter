# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/limited"
require "async/limiter/timing/fixed_window"
require "async/limiter/timing/leaky_bucket"
require "async/limiter/a_limiter"
require "async/limiter/a_semaphore"

describe Async::Limiter::Limited do
	it_behaves_like Async::Limiter::ALimiter
	it_behaves_like Async::Limiter::ASemaphore
	
	with "small limit" do
		include Sus::Fixtures::Async::SchedulerContext

		let(:limiter) {subject.new(2)}
		
		it "enforces the limit" do
			expect(limiter.limit).to be == 2
			expect(limiter).not.to be(:limited?)
		end
		
		it "enforces the limit" do
			expect(limiter.limit).to be == 2
			expect(limiter).not.to be(:limited?)
		end
		
		with "#limit=" do
			it "supports dynamic limit adjustment" do
				expect(limiter.limit).to be == 2
				
				limiter.limit = 5
				expect(limiter.limit).to be == 5
				
				expect do
					limiter.limit = 0
				end.to raise_exception(ArgumentError)
				expect do
					limiter.limit = -1
				end.to raise_exception(ArgumentError)
			end
		end
		
		it "supports timeout parameter" do
			# Fill the limiter to capacity
			limiter.acquire  # 1/2
			limiter.acquire  # 2/2
			
			# Non-blocking should fail when at capacity
			expect(limiter.acquire(timeout: 0)).to be == nil
			
			# Release one resource
			limiter.release
			
			# Non-blocking should now succeed
			expect(limiter.acquire(timeout: 0)).to be == true
		end
		
		it "handles deadline timeouts during condition variable waits" do
			# Fill limiter to capacity
			limiter.acquire  # 1/2
			limiter.acquire  # 2/2
			
			# Try to acquire with very short deadline - should timeout
			start_time = Time.now
			result = limiter.acquire(timeout: 0.01)  # 10ms deadline
			elapsed = Time.now - start_time
			
			expect(result).to be == nil     # Should timeout
			expect(elapsed).to be < 0.1     # Should fail quickly
			expect(elapsed).to be >= 0.005  # But should have tried for some time
		end
		
		it "handles deadline expiry during condition variable waits" do
			# Fill limiter to capacity
			limiter.acquire  # 1/2  
			limiter.acquire  # 2/2
			
			deadline_expired = false
			
			# Start a task that will block and timeout
			blocking_task = reactor.async do
				start_time = Time.now
				result = limiter.acquire(timeout: 0.1)  # 100ms deadline
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
			# Fill limiter to capacity
			limiter.acquire  # 1/2
			limiter.acquire  # 2/2
			
			# Start an async task that will actually block on condition variable
			timeout_task = reactor.async do
				# Use a longer timeout that will actually trigger @condition.wait timeout
				limiter.acquire(timeout: 0.05)  # 50ms timeout
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
		
		with "non-blocking acquire" do
			let(:limiter) {subject.new(1)}
			
			it "does not block" do
				limiter.acquire
				results = []
				
				# Start multiple tasks with different timeouts:
				tasks = [
						Async{limiter.acquire(timeout: 0.002); results << "Long timeout."},
						Async{limiter.acquire(timeout: 0);     results << "Non-blocking."},
						Async{limiter.acquire(timeout: 0.001); results << "Short timeout."},
						Async{limiter.acquire(timeout: 0);     results << "Non-blocking."},
					]
				
				tasks.map(&:wait)
				expect(results).to be == ["Non-blocking.", "Non-blocking.", "Short timeout.", "Long timeout."]
			end
		end
	end

	with "greedy fixed window" do
		include Sus::Fixtures::Async::SchedulerContext
		
		let(:timing) {Async::Limiter::Timing::FixedWindow.new(1.0, Async::Limiter::Timing::BurstStrategy::Greedy, 2)}
		
		# High concurrency limit, low timing limit:
		let(:limiter) {Async::Limiter::Limited.new(10, timing: timing)}
		
		it "prevents timing limit violations under concurrent access" do
			results = []
			
			# Start many concurrent acquire operations
			tasks = 10.times.map do |i|
				reactor.async do
					if limiter.acquire(timeout: 0)
						results << i
						limiter.release
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
					if limiter.acquire(timeout: 0)
						successful_acquisitions += 1
						limiter.release
					end
				end
			end
			
			tasks.each(&:wait)
			
			# Timing limit should be enforced
			expect(successful_acquisitions).to be <= 2
		end
	end
end
