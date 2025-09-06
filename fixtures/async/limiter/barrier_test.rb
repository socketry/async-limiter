# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/barrier"

module Async
	module Limiter
		BarrierTest = Sus::Shared("barrier test") do
			let(:capacity) {2}
			let(:barrier) {Async::Barrier.new}
			let(:repeats) {capacity * 2}
			
			it "executes several tasks and waits using a barrier" do
				limiter_instance = subject.new
				
				repeats.times do
					limiter_instance.async(parent: barrier) do |task|
						task.sleep 0.1
					end
				end
				
				expect(barrier.size).to be == repeats
				barrier.wait
			end
		end
	end
end
