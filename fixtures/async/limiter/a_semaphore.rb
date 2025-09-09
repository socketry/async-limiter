# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Limiter
		ASemaphore = Sus::Shared("a semaphore") do
			let(:limiter) {subject.new}
			
			it "can acquire with timeout" do
				expect(limiter.acquire).to be == true
				expect(limiter.acquire(timeout: 0)).to be_falsey
			end
		end
	end
end
