# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "async/limiter"
require "async/queue"
require "sus/fixtures/async/scheduler_context"

describe Async::Limiter do
	include Sus::Fixtures::Async::SchedulerContext
	
	
	with "Class hierarchy" do
		it "provides Limited semaphore" do
			limiter = Async::Limiter::Limited.new(3)
			
			expect(limiter).to be_a(Async::Limiter::Generic)
			expect(limiter.limit).to be == 3
			expect(limiter.count).to be == 0
		end
		
		it "provides Queued semaphore" do
			queue = Async::Queue.new
			limiter = Async::Limiter::Queued.new(queue)
			
			expect(limiter).to be_a(Async::Limiter::Generic)
			expect(limiter.queue).to be == queue
		end
	end
end
