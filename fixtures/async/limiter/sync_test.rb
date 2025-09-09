# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2025, by Samuel Williams.

module Async
	module Limiter
		SyncTest = Sus::Shared("sync test") do
			with "without a block" do
				it "raises an error" do
					expect {limiter.sync}.to raise_exception(LocalJumpError)
				end
			end
			
			with "with a block" do
				attr_accessor :value
				
				before do
					self.value = nil
					
					limiter.sync do
						Async::Task.current.sleep(0.01)
						self.value = "value"
					end
				end
				
				it "performs the work synchronously" do
					expect(value).to be == "value"
				end
			end
		end
	end
end
