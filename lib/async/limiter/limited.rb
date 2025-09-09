# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "generic"

module Async
	module Limiter
		# Limited concurrency limiter that enforces a strict task limit.
		#
		# This implements a counting semaphore that limits the number of concurrent
		# operations. It coordinates with timing strategies to provide both concurrency
		# and rate limiting.
		#
		# The Limited limiter uses a mutex and condition variable for thread-safe
		# coordination, with support for deadline-aware timeout handling.
		class Limited < Generic
			# Initialize a limited concurrency limiter.
			# @parameter limit [Integer] Maximum concurrent tasks allowed.
			# @parameter timing [#can_acquire?, #acquire, #wait, #maximum_cost] Strategy for timing constraints.
			# @parameter parent [Async::Task, nil] Parent task for creating child tasks.
			# @raises [ArgumentError] If limit is not positive.
			def initialize(limit, timing: Timing::None, parent: nil)
				raise ArgumentError, "Limit must be positive!" unless limit.positive?
				
				super(timing: timing, parent: parent)
				@limit = limit
				@count = 0
				@mutex = Mutex.new
				@condition = ConditionVariable.new
			end
			
			# @attribute [Integer] The maximum number of concurrent tasks.
			attr_reader :limit
			
			# @attribute [Integer] Current count of active tasks.
			attr_reader :count
			
			# Check if a new task can be acquired.
			# @returns [Boolean] True if under the limit.
			def can_acquire?
				@mutex.synchronize {@count < @limit}
			end
			
			# Release a previously acquired resource.
			def release(resource = nil)
				@mutex.synchronize do
					@count -= 1
					@condition.signal
				end
			end
			
			# Update the concurrency limit.
			# @parameter new_limit [Integer] The new maximum number of concurrent tasks.
			# @raises [ArgumentError] If new_limit is not positive.
			def limit=(new_limit)
				raise ArgumentError, "Limit must be positive!" unless new_limit.positive?
				
				@mutex.synchronize do
					old_limit = @limit
					@limit = new_limit
					# Wake up waiting tasks if limit increased:
					@condition.broadcast if new_limit > old_limit
				end
			end
			
			protected
			
			# Acquire concurrency resource with optional deadline.
			def acquire_concurrency(deadline = nil, **options)
				@mutex.synchronize do
					# Fast path: immediate return for expired deadlines, but only if at capacity
					return nil if deadline&.expired? && @count >= @limit
					
					# Wait for capacity with deadline tracking
					while @count >= @limit
						remaining = deadline&.remaining
						return nil if remaining && remaining <= 0
						
						unless @condition.wait(@mutex, remaining)
							return nil  # Timeout exceeded
						end
					end
					
					@count += 1
					true
				end
			end
		end
	end
end
