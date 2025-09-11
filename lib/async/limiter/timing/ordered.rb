# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "async/condition"

module Async
	module Limiter
		module Timing
			# Ordered timing strategy wrapper that preserves FIFO ordering.
			#
			# This wrapper delegates to any timing strategy but ensures that tasks
			# acquire capacity in the order they requested it, preventing starvation
			# of high-cost operations by continuous low-cost operations.
			class Ordered
				# Initialize ordered timing wrapper.
				# @parameter delegate [#acquire, #wait, #maximum_cost] The timing strategy to wrap.
				def initialize(delegate)
					@delegate = delegate
					@mutex = Mutex.new
				end
				
				# Get maximum cost from delegate strategy.
				# @returns [Numeric] Maximum supported cost.
				def maximum_cost
					@delegate.maximum_cost
				end
				
				# Record acquisition in delegate strategy.
				# @parameter cost [Numeric] Cost of the operation.
				def acquire(cost = 1)
					@delegate.acquire(cost)
				end
				
				# Wait with FIFO ordering preserved.
				# @parameter mutex [Mutex] Mutex to release during sleep.
				# @parameter deadline [Deadline, nil] Deadline for timeout.
				# @parameter cost [Numeric] Cost of the operation.
				# @returns [Boolean] True if acquired, false if timed out.
				def wait(mutex, deadline = nil, cost = 1)
					@mutex.synchronize do
						@delegate.wait(mutex, deadline, cost)
					end
				end
			end
		end
	end
end
