# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/timing/none"
require "sus/fixtures/async/scheduler_context"

describe Async::Limiter::Timing::None do
	include Sus::Fixtures::Async::SchedulerContext
	
	it "always allows acquisition" do
		expect(subject.can_acquire?).to be == true
	end
	
	it "wait returns immediately" do
		start_time = Time.now
		subject.wait(nil, nil)  # mutex, deadline both nil
		end_time = Time.now
		
		duration = end_time - start_time
		expect(duration).to be < 0.01  # Should be immediate
	end
	
	it "acquire is a no-op" do
		# Should not raise any errors
		subject.acquire
		subject.acquire
	end
end
