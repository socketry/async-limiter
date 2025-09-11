# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/timing/burst"

describe Async::Limiter::Timing::Burst do
	with "Greedy" do
		let(:strategy) {Async::Limiter::Timing::Burst::Greedy}
		
		it "allows acquisition when under limit" do
			expect(strategy.can_acquire?(2, 5, false)).to be == true
			expect(strategy.can_acquire?(4, 5, true)).to be == true
		end
		
		it "blocks when at limit" do
			expect(strategy.can_acquire?(5, 5, false)).to be == false
		end
		
		it "calculates next acquire time as next window" do
			next_time = strategy.next_acquire_time(100, 60, 120, 10)
			expect(next_time).to be == 160  # 100 + 60
		end
		
		it "window blocking depends on window state" do
			expect(strategy.window_blocking?(3, 5, true)).to be == false   # Window changed
			expect(strategy.window_blocking?(5, 5, false)).to be == true   # At limit
		end
		
		it "frame blocking is always false for greedy" do
			expect(strategy.frame_blocking?(true)).to be == false
			expect(strategy.frame_blocking?(false)).to be == false
		end
	end
	
	with "Smooth" do
		let(:strategy) {Async::Limiter::Timing::Burst::Smooth}
		
		it "only allows acquisition when frame changed" do
			expect(strategy.can_acquire?(0, 5, true)).to be == true   # Frame changed
			expect(strategy.can_acquire?(2, 5, false)).to be == false # Frame not changed
		end
		
		it "calculates next acquire time as next frame" do
			next_time = strategy.next_acquire_time(100, 60, 120, 10)
			expect(next_time).to be == 130  # 120 + 10
		end
		
		it "window blocking is always false for smooth" do
			expect(strategy.window_blocking?(5, 5, false)).to be == false
		end
		
		it "frame blocking depends on frame state" do
			expect(strategy.frame_blocking?(true)).to be == false   # Frame changed
			expect(strategy.frame_blocking?(false)).to be == true   # Frame not changed
		end
	end
end
