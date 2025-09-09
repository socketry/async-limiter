# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2025, by Samuel Williams.

module Async
	module Limiter
		AcquireWithBlock = Sus::Shared("acquire with block") do
			attr_accessor :value
			
			before do
				self.value = nil
				
				limiter.acquire do
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
