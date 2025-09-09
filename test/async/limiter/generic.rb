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
end
