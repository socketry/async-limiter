# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/timing/leaky_bucket"
require "async/clock"
require "async/deadline"
require "sus/fixtures/async/scheduler_context"

describe Async::Limiter::Timing::LeakyBucket do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:bucket) {subject.new(2.0, 5.0)}  # Traditional leaky bucket: starts empty
	
	it "can be created with rate and capacity" do
		expect(bucket.rate).to be == 2.0
		expect(bucket.capacity).to be == 5.0
	end
	
	it "starts allowing acquisitions" do
		expect(bucket.can_acquire?).to be == true
	end
	
	it "tracks acquisitions up to capacity" do
		# Use zero leak rate to test pure capacity behavior
		no_leak_bucket = subject.new(0.0, 5.0)
		
		5.times do
			expect(no_leak_bucket.can_acquire?).to be == true
			no_leak_bucket.acquire
		end
		
		# Should be at capacity now
		expect(no_leak_bucket.can_acquire?).to be == false
	end
	
	it "leaks over time" do
		# Test the leaking behavior by starting with a full bucket and advancing time
		leaking_bucket = subject.new(2.0, 3.0)
		leaking_bucket.level = 3.0  # Set to full
		
		# Advance time immediately to simulate leaking without timing race conditions
		leaking_bucket.advance_time(0.5)  # 0.5 seconds = 1 unit leaked at 2 units/sec
		
		# Should now have capacity and level should be reduced
		expect(leaking_bucket.can_acquire?).to be == true
		expect(leaking_bucket.level).to be_within(0.1).of(2.0)  # Should have leaked 1 unit
	end
	
	
	it "allows level to exceed capacity" do
		# Use zero leak rate for precise testing
		no_leak_bucket = subject.new(0.0, 5.0)
		
		# Fill beyond capacity
		10.times {no_leak_bucket.acquire}
		expect(no_leak_bucket.level).to be == 10.0  # Level can exceed capacity
		expect(no_leak_bucket.can_acquire?).to be == false  # But still blocks new requests
	end
	
	it "handles rapid acquisition and leaking" do
		# Rapid acquisitions
		3.times {bucket.acquire}
		initial_level = bucket.level
		
		# Simulate time passing (1.0 second = 2 units should leak out at 2 units/sec)
		bucket.advance_time(1.0)
		
		final_level = bucket.level
		expect(final_level).to be < initial_level
		expect(final_level).to be_within(0.1).of(1.0)  # Should be about 1 unit left
	end
	
	with "Different initial levels" do
		it "supports starting empty (traditional leaky bucket)" do
			empty_bucket = subject.new(2.0, 5.0, initial_level: 0)
			expect(empty_bucket.level).to be == 0.0
			expect(empty_bucket.can_acquire?).to be == true
		end
		
		it "supports starting full (token bucket behavior)" do
			# Use zero rate to test exact full behavior
			full_bucket = subject.new(0.0, 5.0, initial_level: 5.0)
			expect(full_bucket.level).to be == 5.0
			expect(full_bucket.can_acquire?).to be == false  # Full, no more capacity
			
			# Test that leaking creates capacity
			leaking_bucket = subject.new(2.0, 5.0, initial_level: 5.0)
			leaking_bucket.advance_time(0.5)  # 1 unit leaks out
			expect(leaking_bucket.can_acquire?).to be == true
		end
		
		it "supports starting at any level" do
			half_bucket = subject.new(2.0, 10.0, initial_level: 5.0)
			expect(half_bucket.level).to be_within(0.1).of(5.0)
			expect(half_bucket.can_acquire?).to be == true  # Still has capacity
		end
		
		it "allows initial level higher than capacity" do
			# This just means it will take longer to have capacity
			overfull_bucket = subject.new(2.0, 5.0, initial_level: 10.0)
			expect(overfull_bucket.level).to be_within(0.1).of(10.0)
			expect(overfull_bucket.can_acquire?).to be == false
			
			# Simulate time passing to leak down to capacity
			overfull_bucket.advance_time(3.0)  # 6 units leak out
			expect(overfull_bucket.level).to be_within(0.1).of(4.0)
			expect(overfull_bucket.can_acquire?).to be == true
		end
		
		it "supports cost-based acquisition" do
			# Use zero leak rate for precise testing
			bucket = subject.new(0.0, 5.0)  # 0 leak rate, capacity 5
			
			# Should support different costs
			expect(bucket.can_acquire?(1)).to be == true
			expect(bucket.can_acquire?(2.5)).to be == true
			expect(bucket.can_acquire?(5.0)).to be == true
			expect(bucket.can_acquire?(5.1)).to be == false  # Exceeds capacity
			
			# Acquire with different costs
			bucket.acquire(2.0)
			expect(bucket.level).to be_within(0.01).of(2.0)
			
			bucket.acquire(1.5)
			expect(bucket.level).to be_within(0.01).of(3.5)
			
			# Should not be able to acquire cost that would exceed capacity
			expect(bucket.can_acquire?(2.0)).to be == false  # 3.5 + 2.0 > 5.0
			expect(bucket.can_acquire?(1.5)).to be == true   # 3.5 + 1.5 = 5.0
		end
		
		it "validates maximum cost" do
			bucket = subject.new(1.0, 3.0)  # Capacity 3
			expect(bucket.maximum_cost).to be == 3.0
		end
	end
	
	with "#wait with deadlines" do
		it "waits until it can acquire" do
			bucket = subject.new(1.0, 2.0, initial_level: 0.0)
			result = bucket.wait(Kernel, nil, 1.0)
			expect(result).to be == true
		end
		
		it "returns false immediately for expired deadlines" do
			# Create a full bucket so it would normally need to wait
			bucket = subject.new(1.0, 2.0, initial_level: 2.0)
			
			# Create an already expired deadline
			expired_deadline = Async::Deadline.new(0.001)
			sleep(0.002)  # Ensure deadline is expired
			
			result = bucket.wait(Kernel, expired_deadline, 1.0)
			expect(result).to be == false
		end
		
		it "returns false when wait time would exceed deadline" do
			# Create a full bucket with slow leak rate
			bucket = subject.new(1.0, 2.0, initial_level: 2.0)  # Rate 1.0/sec, full at 2.0
			
			# Create a short deadline (100ms)
			short_deadline = Async::Deadline.new(0.1)
			
			# Trying to acquire cost 1.0 would require ~1 second to leak enough space
			# But deadline is only 100ms, so should return false
			result = bucket.wait(Kernel, short_deadline, 1.0)
			expect(result).to be == false
		end
	end
end
