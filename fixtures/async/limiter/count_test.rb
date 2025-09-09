# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2025, by Samuel Williams.

module Async
	module Limiter
		CountTest = Sus::Shared("count test") do
			with "default" do
				it "is zero" do
					expect(limiter.count).to be == 0
				end
			end
			
			with "when a lock is acquired" do
				it "increments count" do
					limiter.acquire
					expect(limiter.count).to be == 1
				end
			end
			
			with "when a lock is acquired and then released" do
				it "resets count" do
					limiter.acquire
					limiter.release
					expect(limiter.count).to be == 0
				end
			end
		end
	end
end
