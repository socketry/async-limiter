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
		let(:semaphore) {Async::Limiter::Queued.new(queue)}
		
		it "starts empty and blocking" do
			expect(semaphore).to be(:limited?)
			expect(semaphore.acquire(timeout: 0)).to be == nil
		end
		
		it "can add resources via release" do
			3.times {semaphore.release("resource")}
			expect(semaphore).not.to be(:limited?)
			expect(semaphore.acquire(timeout: 0)).to be == "resource"
		end
		
		it "acquires resources from queue" do
			semaphore.release("test_resource")
			
			result = semaphore.acquire
			expect(result).to be == "test_resource"
			expect(semaphore).to be(:limited?)
		end
		
		it "supports acquire with block and auto-release" do
			semaphore.release("block_resource")
			
			result = nil
			semaphore.acquire do
				result = "executed"
			end
			
			expect(result).to be == "executed"
			# Resource should be returned to queue
			expect(semaphore).not.to be(:limited?)
		end
		
		it "supports non-blocking acquire" do
			expect(semaphore.acquire(timeout: 0)).to be == nil  # Empty queue returns false
			
			semaphore.release("resource")
			expect(semaphore.acquire(timeout: 0)).to be == "resource"
		end
		
		it "supports non-blocking acquire with block" do
			semaphore.release("test_resource")
			
			result = nil
			resource = semaphore.acquire(timeout: 0) do
				result = "executed"
			end
			
			expect(resource).to be == "executed"  # Block return value
			expect(result).to be == "executed"
			
			# Resource returned:
			expect(semaphore).not.to be(:limited?)
		end
		
		it "supports priority and timeout options" do
			semaphore.release("priority_resource")
			
			# Test that options are accepted and forwarded to queue
			result = semaphore.acquire(timeout: 1.0)
			expect(result).to be == "priority_resource"
			expect(semaphore).to be(:limited?)
		end
		
		it "supports expand method to add resources" do
			# Start with empty queue
			expect(semaphore).to be(:limited?)
			
			# Expand with multiple resources
			semaphore.expand(3, "expanded_resource")
			
			# Should now have resources available
			expect(semaphore).not.to be(:limited?)
			
			# Should be able to acquire the expanded resources
			expect(semaphore.acquire(timeout: 0)).to be == "expanded_resource"
			expect(semaphore.acquire(timeout: 0)).to be == "expanded_resource"
			expect(semaphore.acquire(timeout: 0)).to be == "expanded_resource"
			
			# Should be empty again
			expect(semaphore).to be(:limited?)
		end
	end
end
