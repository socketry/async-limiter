# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/generic"
require "async/limiter/a_limiter"

describe Async::Limiter::Generic do
	it_behaves_like Async::Limiter::ALimiter
	
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:semaphore) {Async::Limiter::Generic.new}
	
	it "allows unlimited acquisitions" do
		100.times do
			semaphore.acquire
		end
		expect(semaphore.acquire(timeout: 0)).to be == true
	end
	
	it "supports acquire with block" do
		result = nil
		semaphore.acquire do
			result = "executed"
		end
		expect(result).to be == "executed"
	end
	
	it "supports non-blocking acquire" do
		expect(semaphore.acquire(timeout: 0)).to be == true
	end
	
	it "supports timeout parameter" do
		# Non-blocking (timeout: 0)
		expect(semaphore.acquire(timeout: 0)).to be == true
		
		# Blocking with timeout (should succeed immediately for unlimited)
		expect(semaphore.acquire(timeout: 1.0)).to be == true
		
		# Blocking without timeout (should succeed immediately for unlimited)
		expect(semaphore.acquire(timeout: nil)).to be == true
	end
	
	it "supports non-blocking acquire with block" do
		result = nil
		resource = semaphore.acquire(timeout: 0) do
			result = "executed"
		end
		expect(resource).to be == "executed"  # Block return value
		expect(result).to be == "executed"
	end
	
	it "supports async execution" do
		results = []
		
		tasks = 5.times.map do |i|
			semaphore.async do |task|
				results << i
			end
		end
		
		tasks.each(&:wait)
		expect(results.size).to be == 5
	end
	
	it "supports sync execution" do
		result = nil
		semaphore.sync do |task|
			result = task
		end
		expect(result).to be_a(Async::Task)
	end
	
	it "supports cost-based acquisition" do
		# Cost parameter should be accepted (no timing constraints)
		expect(semaphore.acquire(cost: 0.5)).to be == true
		expect(semaphore.acquire(cost: 1.0)).to be == true  
		expect(semaphore.acquire(cost: 2.5)).to be == true
		
		# Should work with timeout too
		expect(semaphore.acquire(timeout: 0, cost: 1.5)).to be == true
		
		# Even very large costs should work (no timing constraints)
		expect(semaphore.acquire(cost: 1000.0)).to be == true
	end
	
	with "#acquire_token" do
		it "supports acquire_token without block" do
			token = semaphore.acquire_token
			
			expect(token).to be_a(Async::Limiter::Token)
			expect(token.resource).to be == true  # Generic returns true
			expect(token.released?).to be == false
			
			token.release
			expect(token.released?).to be == true
			expect(token.resource).to be == nil
		end
		
		it "supports acquire_token with block" do
			result = nil
			return_value = semaphore.acquire_token do |token|
				expect(token).to be_a(Async::Limiter::Token)
				expect(token.resource).to be == true
				expect(token.released?).to be == false
				result = "executed"
			end
			
			expect(return_value).to be == "executed"  # Block return value
			expect(result).to be == "executed"
		end
		
		it "supports token re-acquisition" do
			token = semaphore.acquire_token(timeout: 1.0, cost: 2.0)
			expect(token.resource).to be == true
			
			# Re-acquire with different options (returns same token, updated)
			same_token = token.acquire(timeout: 0.5, cost: 1.5)
			expect(same_token).to be == token  # Same token object
			expect(token.resource).to be == true  # Still has resource
			expect(token.released?).to be == false  # Not released, just re-acquired
		end
		
		it "supports token re-acquisition with block" do
			token = semaphore.acquire_token
			
			result = nil
			block_result = token.acquire(cost: 3.0) do |resource|
				expect(resource).to be == true  # Resource, not token
				result = "reacquired"
			end
			
			expect(block_result).to be == "reacquired"  # Block return value
			expect(result).to be == "reacquired"
			expect(token.released?).to be == false  # Token still active after re-acquisition
		end
		
		it "handles double release gracefully" do
			token = semaphore.acquire_token
			
			token.release
			expect(token.released?).to be == true
			
			# Second release should be safe
			token.release
			expect(token.released?).to be == true
		end
	end
end
