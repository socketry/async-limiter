# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "async/clock"

module Async
	module Limiter
		# @namespace
		module Timing
			# No timing constraints - tasks can execute immediately.
			#
			# This strategy provides no time-based limiting, suitable for
			# pure concurrency control without rate limiting.
			module None
				# Maximum cost this timing strategy can support (unlimited for no constraints).
				# @returns [Float] Infinity since there are no timing constraints.
				def self.maximum_cost
					Float::INFINITY
				end
				# Check if a task can be acquired (always true for no timing constraints).
				# @parameter cost [Numeric] Cost of the operation (ignored for no timing constraints).
				# @returns [Boolean] Always true.
				def self.can_acquire?(cost = 1)
					true
				end
				
				# Record that a task was acquired (no-op for this strategy).
				# @parameter cost [Numeric] Cost of the operation (ignored for no timing constraints).
				def self.acquire(cost = 1)
					# No state to update
				end
				
				# Wait for timing constraints to be satisfied (no-op for this strategy).
				# @parameter mutex [Mutex] Mutex to release during sleep (ignored for no timing constraints).
				# @parameter deadline [Deadline, nil] Deadline for timeout (ignored for no timing constraints).
				# @parameter cost [Numeric] Cost of the operation (ignored for no timing constraints).
				# @returns [Boolean] Always true since there are no timing constraints.
				def self.wait(mutex, deadline = nil, cost = 1)
					# No waiting needed - return immediately
					true
				end
				
				# Get current timing strategy statistics.
				# @returns [Hash] Statistics hash with current state.
				def self.statistics
					{
						name: "None"
					}
				end
			end
		end
	end
end
