# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/queued"
require "async/queue"
require "async/priority_queue"
require "sus/fixtures/async/scheduler_context"

describe Async::Limiter::Queued do
	it_behaves_like Async::Limiter::ALimiter
	
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:queue) {Async::Queue.new}
	let(:semaphore) {Async::Limiter::Queued.new(queue)}
	
	it "starts empty and blocking" do
		expect(semaphore.can_acquire?).to be == false
		expect(semaphore.acquire(timeout: 0)).to be == nil
	end
	
	it "can add resources via release" do
		3.times {semaphore.release("resource")}
		expect(semaphore.can_acquire?).to be == true
		expect(semaphore.acquire(timeout: 0)).to be == "resource"
	end
	
	it "acquires resources from queue" do
		semaphore.release("test_resource")
		
		result = semaphore.acquire
		expect(result).to be == "test_resource"
		expect(semaphore.can_acquire?).to be == false
	end
	
	it "supports acquire with block and auto-release" do
		semaphore.release("block_resource")
		
		result = nil
		semaphore.acquire do
			result = "executed"
		end
		
		expect(result).to be == "executed"
		# Resource should be returned to queue
		expect(semaphore.can_acquire?).to be == true
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
		expect(semaphore.can_acquire?).to be == true  # Resource returned
	end
	
	it "supports priority and timeout options" do
		semaphore.release("priority_resource")
		
		# Test that options are accepted and forwarded to queue
		result = semaphore.acquire(timeout: 1.0)
		expect(result).to be == "priority_resource"
		expect(semaphore.can_acquire?).to be == false
	end
	
	it "supports expand method to add resources" do
		# Start with empty queue
		expect(semaphore.can_acquire?).to be == false
		
		# Expand with multiple resources
		semaphore.expand(3, "expanded_resource")
		
		# Should now have resources available
		expect(semaphore.can_acquire?).to be == true
		
		# Should be able to acquire the expanded resources
		expect(semaphore.acquire(timeout: 0)).to be == "expanded_resource"
		expect(semaphore.acquire(timeout: 0)).to be == "expanded_resource"
		expect(semaphore.acquire(timeout: 0)).to be == "expanded_resource"
		
		# Should be empty again
		expect(semaphore.can_acquire?).to be == false
	end
	
	with "#acquire_token" do
		it "supports acquire_token with resources" do
			semaphore.release("token_resource")
			
			token = semaphore.acquire_token
			
			expect(token).to be_a(Async::Limiter::Token)
			expect(token.resource).to be == "token_resource"  # Actual resource from queue
			expect(token.released?).to be == false
			
			token.release
			expect(token.released?).to be == true
			expect(semaphore.can_acquire?).to be == true  # Resource returned to queue
		end
		
		it "supports token with timeout" do
			# Empty queue
			token = semaphore.acquire_token(timeout: 0)
			
			# Should get nil resource due to timeout
			expect(token.resource).to be == nil
			expect(token.released?).to be == true
		end
	end
end
