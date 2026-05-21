# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "async/limiter"
require "async/queue"
require "async/utilization"
require "sus/fixtures/async/scheduler_context"

describe "Async::Limiter utilization metrics" do
	let(:registry) {Async::Utilization::Registry.new}
	
	with Async::Limiter::Limited do
		let(:limiter) {Async::Limiter::Limited.new(2, utilization: registry.namespace(:limited))}
		
		it "initializes utilization metrics" do
			limiter
			
			expect(limiter.acquired_count).to be == 0
			expect(limiter.available_count).to be == 2
			expect(limiter.waiting_count).to be == 0
			expect(limiter.reacquire_waiting_count).to be == 0
			
			expect(registry.values).to have_keys(
				limited_acquired_count: be == 0,
				limited_available_count: be == 2,
				limited_waiting_count: be == 0,
				limited_reacquire_waiting_count: be == 0
			)
		end
		
		it "updates utilization metrics when resources are acquired and released" do
			resource = limiter.acquire
			
			expect(limiter.acquired_count).to be == 1
			expect(limiter.available_count).to be == 1
			
			expect(registry.values).to have_keys(
				limited_acquired_count: be == 1,
				limited_available_count: be == 1
			)
			
			limiter.release(resource)
			
			expect(registry.values).to have_keys(
				limited_acquired_count: be == 0,
				limited_available_count: be == 2
			)
		end
		
		it "updates utilization metrics when the limit changes" do
			limiter.limit = 3
			
			expect(registry.values).to have_keys(
				limited_acquired_count: be == 0,
				limited_available_count: be == 3
			)
		end
		
		it "updates waiting utilization metrics" do
			limiter.acquire
			limiter.acquire
			
			thread = Thread.new do
				limiter.acquire(reacquire: true)
			end
			
			Thread.pass until registry.values[:limited_reacquire_waiting_count] == 1
			
			expect(registry.values).to have_keys(
				limited_waiting_count: be == 1,
				limited_reacquire_waiting_count: be == 1
			)
			
			limiter.release
			expect(thread.value).to be == true
			
			expect(registry.values).to have_keys(
				limited_waiting_count: be == 0,
				limited_reacquire_waiting_count: be == 0
			)
		end
	end
	
	with Async::Limiter::Queued do
		include Sus::Fixtures::Async::SchedulerContext
		
		let(:queue) {Async::Queue.new}
		let(:limiter) {Async::Limiter::Queued.new(queue, utilization: registry.namespace(:queued))}
		
		it "initializes utilization metrics" do
			limiter
			
			expect(limiter.acquired_count).to be == 0
			expect(limiter.available_count).to be == 0
			expect(limiter.waiting_count).to be == 0
			expect(limiter.reacquire_waiting_count).to be == 0
			
			expect(registry.values).to have_keys(
				queued_acquired_count: be == 0,
				queued_available_count: be == 0,
				queued_waiting_count: be == 0,
				queued_reacquire_waiting_count: be == 0
			)
		end
		
		it "updates utilization metrics when resources are acquired and released" do
			limiter.release("resource")
			
			expect(limiter.available_count).to be == 1
			
			expect(registry.values).to have_keys(
				queued_acquired_count: be == 0,
				queued_available_count: be == 1
			)
			
			resource = limiter.acquire(timeout: 0)
			expect(resource).to be == "resource"
			
			expect(limiter.acquired_count).to be == 1
			expect(limiter.available_count).to be == 0
			
			expect(registry.values).to have_keys(
				queued_acquired_count: be == 1,
				queued_available_count: be == 0
			)
			
			limiter.release(resource)
			
			expect(registry.values).to have_keys(
				queued_acquired_count: be == 0,
				queued_available_count: be == 1
			)
		end
		
		it "updates reacquire utilization metrics" do
			task = reactor.async do
				limiter.acquire(reacquire: true)
			end
			
			sleep 0.01 until registry.values[:queued_reacquire_waiting_count] == 1
			
			expect(limiter.waiting_count).to be == 1
			expect(limiter.reacquire_waiting_count).to be == 1
			
			expect(registry.values).to have_keys(
				queued_reacquire_waiting_count: be == 1
			)
			
			limiter.release("resource")
			
			expect(task.wait).to be == "resource"
			
			expect(registry.values).to have_keys(
				queued_acquired_count: be == 1,
				queued_reacquire_waiting_count: be == 0
			)
		end
	end
end
