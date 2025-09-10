# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/queue"
require "async/priority_queue"

require "async/limiter/queued"
require "async/limiter/a_limiter"
require "async/limiter/a_semaphore"

describe Async::Limiter::Queued do
	it_behaves_like Async::Limiter::ALimiter
	it_behaves_like Async::Limiter::ASemaphore
	
	with "empty queue" do
		include Sus::Fixtures::Async::SchedulerContext
		
		let(:queue) {Async::Queue.new}
		let(:limiter) {Async::Limiter::Queued.new(queue)}
		
		it "starts empty and blocking" do
			expect(limiter).to be(:limited?)
			expect(limiter.acquire(timeout: 0)).to be == nil
		end
		
		it "can add resources via release" do
			3.times {limiter.release("resource")}
			expect(limiter).not.to be(:limited?)
			expect(limiter.acquire(timeout: 0)).to be == "resource"
		end
		
		it "acquires resources from queue" do
			limiter.release("test_resource")
			
			result = limiter.acquire
			expect(result).to be == "test_resource"
			expect(limiter).to be(:limited?)
		end
		
		it "supports acquire with block and auto-release" do
			limiter.release("block_resource")
			
			result = nil
			limiter.acquire do
				result = "executed"
			end
			
			expect(result).to be == "executed"
			# Resource should be returned to queue
			expect(limiter).not.to be(:limited?)
		end
		
		it "supports non-blocking acquire" do
			expect(limiter.acquire(timeout: 0)).to be == nil  # Empty queue returns false
			
			limiter.release("resource")
			expect(limiter.acquire(timeout: 0)).to be == "resource"
		end
		
		it "supports non-blocking acquire with block" do
			limiter.release("test_resource")
			
			result = nil
			resource = limiter.acquire(timeout: 0) do
				result = "executed"
			end
			
			expect(resource).to be == "executed"  # Block return value
			expect(result).to be == "executed"
			
			# Resource returned:
			expect(limiter).not.to be(:limited?)
		end
		
		it "supports priority and timeout options" do
			limiter.release("priority_resource")
			
			# Test that options are accepted and forwarded to queue
			result = limiter.acquire(timeout: 1.0)
			expect(result).to be == "priority_resource"
			expect(limiter).to be(:limited?)
		end
		
		it "supports expand method to add resources" do
			# Start with empty queue
			expect(limiter).to be(:limited?)
			
			# Expand with multiple resources
			limiter.expand(3, "expanded_resource")
			
			# Should now have resources available
			expect(limiter).not.to be(:limited?)
			
			# Should be able to acquire the expanded resources
			expect(limiter.acquire(timeout: 0)).to be == "expanded_resource"
			expect(limiter.acquire(timeout: 0)).to be == "expanded_resource"
			expect(limiter.acquire(timeout: 0)).to be == "expanded_resource"
			
			# Should be empty again
			expect(limiter).to be(:limited?)
		end
	end
	
	with "priority queue" do
		include Sus::Fixtures::Async::SchedulerContext
		
		let(:queue) {Async::PriorityQueue.new}
		let(:limiter) {Async::Limiter::Queued.new(queue)}
		
		it "executes tasks in priority order" do
			results = []
			
			# Start tasks with different priorities
			tasks = [
				Async do
					limiter.acquire(priority: 1, timeout: 1.0) do |worker|
						results << "Low priority task used #{worker}"
					end
				end,
				
				Async do
					limiter.acquire(priority: 10, timeout: 1.0) do |worker|
						results << "High priority task used #{worker}"
					end
				end,
				
				Async do
					limiter.acquire(priority: 5, timeout: 1.0) do |worker|
						results << "Medium priority task used #{worker}"
					end
				end
			]
			
			sleep 0.5
			
			# Add some "workers":
			2.times do |i|
				limiter.release("worker_#{i}")
			end
			
			tasks.each(&:wait)
			
			expect(results).to be == [
				"High priority task used worker_0",
				"Medium priority task used worker_1",
				"Low priority task used worker_0",
			]
		end
	end
end
