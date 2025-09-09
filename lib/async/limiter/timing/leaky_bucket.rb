# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/clock"

module Async
	module Limiter
		module Timing
			# Leaky bucket timing strategy that smooths traffic flow.
			#
			# This strategy maintains a "bucket" that gradually "leaks" capacity over time,
			# enforcing a steady output rate regardless of input bursts.
			class LeakyBucket
				# @attribute [Numeric] Leak rate in units per second.
				attr_reader :rate
				
				# @attribute [Numeric] Maximum bucket capacity.
				attr_reader :capacity
				
				# Initialize a leaky bucket timing strategy.
				# @parameter rate [Numeric] Leak rate in units per second.
				# @parameter capacity [Numeric] Maximum bucket capacity.
				# @parameter initial_level [Numeric] Starting bucket level (0 = leaky bucket, capacity = token bucket).
				def initialize(rate, capacity, initial_level: 0)
					raise ArgumentError, "rate must be non-negative" unless rate >= 0
					raise ArgumentError, "capacity must be positive" unless capacity.positive?
					
					@rate = rate
					@capacity = capacity
					@level = initial_level.to_f
					@last_leak = Clock.now
				end
				
				# Maximum cost this timing strategy can support.
				# @returns [Numeric] The maximum cost (equal to capacity).
				def maximum_cost
					@capacity
				end
				
				# Check if a task can be acquired with the given cost.
				# @parameter current_time [Numeric] Current time for leak calculations.
				# @parameter cost [Numeric] The cost/weight of the operation.
				# @returns [Boolean] True if bucket has capacity for this cost.
				def can_acquire?(current_time = Clock.now, cost = 1)
					leak_bucket(current_time)
					@level + cost <= @capacity
				end
				
				# Record that a task was acquired (adds cost to bucket level).
				# @parameter cost [Numeric] The cost/weight of the operation.
				def acquire(cost = 1)
					leak_bucket
					@level += cost
				end
				
				# Wait for bucket to have capacity.
				# @parameter mutex [Mutex] Mutex to release during sleep.
				# @parameter deadline [Deadline, nil] Deadline for timeout (nil = wait forever).
				# @parameter cost [Numeric] Cost of the operation (default: 1).
				# @returns [Boolean] True if capacity is available, false if timeout exceeded.
				def wait(mutex, deadline = nil, cost = 1)
					# Loop until we can acquire or deadline expires:
					until can_acquire?(Clock.now, cost)
						# Check deadline before each wait:
						return false if deadline&.expired?
						
						# Calculate how long to wait for bucket to leak enough for this cost:
						needed_capacity = (@level + cost) - @capacity
						wait_time = needed_capacity / @rate.to_f
						
						# Should be able to acquire now:
						return true if wait_time <= 0
						
						# Check if wait would exceed deadline:
						remaining = deadline&.remaining
						if remaining && wait_time > remaining
							# Would exceed deadline:
							return false
						end
						
						# Wait for the required time (or remaining time if deadline specified):
						actual_wait = remaining ? [wait_time, remaining].min : wait_time
						
						# Release mutex during sleep:
						mutex.sleep(actual_wait)
					end
					
					return true
				end
				
				# Get current bucket level (for debugging/monitoring).
				# @returns [Numeric] Current bucket level.
				def level
					leak_bucket
					@level
				end
				
				# Set bucket level (for testing purposes).
				# @parameter new_level [Numeric] New bucket level.
				def level=(new_level)
					@level = new_level.to_f
					@last_leak = Clock.now
				end
				
				# Simulate time advancement for testing purposes.
				# @parameter seconds [Numeric] Number of seconds to advance.
				def advance_time(seconds)
					@last_leak -= seconds
					leak_bucket
				end
				
				private
				
				# Leak the bucket based on elapsed time.
				# @parameter current_time [Numeric] Current time.
				def leak_bucket(current_time = Clock.now)
					return if @level <= 0  # Don't leak if already empty or negative
					
					elapsed = current_time - @last_leak
					leaked = elapsed * @rate
					
					@level = [@level - leaked, 0.0].max
					@last_leak = current_time
				end
			end
		end
	end
end
