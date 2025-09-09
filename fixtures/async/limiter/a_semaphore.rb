# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Limiter
		ASemaphore = Sus::Shared("a semaphore") do
			let(:limiter) {subject.new}
			
			it "can acquire with timeout" do
				expect(limiter.acquire).to be == true
				expect(limiter).to be(:limited?)
				expect(limiter.acquire(timeout: 0)).to be == nil
			end

			it "waits for capacity" do
				limiter.acquire
				
				# This task will wait for capacity:
				thread = Thread.new do
					limiter.acquire(timeout: 0.01)
				end
				
				expect(thread.value).to be == nil
			end
			
			it "releases correctly" do
				limiter.acquire
				limiter.release
				expect(limiter).not.to be(:limited?)
			end
		end
	end
end
