# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/timing/ordered"
require "async/limiter/timing/leaky_bucket"
require "async/limiter/timing/none"
require "async/limiter/limited"
require "sus/fixtures/async/scheduler_context"

describe Async::Limiter::Timing::Ordered do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:ordered) {subject.new(Async::Limiter::Timing::None)}
	
	with "#maximum_cost" do
		it "delegates maximum_cost" do
			expect(ordered.maximum_cost).to be == Float::INFINITY
		end
	end

	with "#acquire" do
		it "delegates acquire" do
			# None strategy doesn't maintain state, so just verify no errors
			ordered.acquire(2.0)
		end
	end
	
	with "#wait with ordering" do
		it "serializes access to delegate timing strategy" do
			result = ordered.wait(Kernel, nil, 1.0)
			expect(result).to be == true
		end
		
		it "handles timeout correctly with LeakyBucket" do
			# Use LeakyBucket for timeout testing since None never times out
			bucket_timing = Async::Limiter::Timing::LeakyBucket.new(1.0, 2.0)
			ordered_bucket = subject.new(bucket_timing)
			
			# Fill bucket to capacity
			2.times { ordered_bucket.acquire(1.0) }
			
			# Should timeout when no capacity available
			deadline = Async::Deadline.new(0.1)
			result = ordered_bucket.wait(Kernel, deadline, 1.0)
			expect(result).to be == false
		end
	end
end