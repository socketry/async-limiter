# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
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
			# @parameter timing [#acquire, #wait, #maximum_cost] Strategy for timing constraints.
			# @parameter parent [Async::Task, nil] Parent task for creating child tasks.
			# @raises [ArgumentError] If limit is not positive.
			def initialize(limit = 1, timing: Timing::None, parent: nil)
				super(timing: timing, parent: parent)
				
				@limit = limit
				@count = 0
				
				@available = ConditionVariable.new
			end
			
			# @attribute [Integer] The maximum number of concurrent tasks.
			attr_reader :limit
			
			# @attribute [Integer] Current count of active tasks.
			attr_reader :count
			
			# Check if a new task can be acquired.
			# @returns [Boolean] True if under the limit.
			def limited?
				@mutex.synchronize{@count >= @limit}
			end
			
			# Update the concurrency limit.
			# @parameter new_limit [Integer] The new maximum number of concurrent tasks.
			# @raises [ArgumentError] If new_limit is not positive.
			def limit=(new_limit)
				@mutex.synchronize do
					old_limit = @limit
					@limit = new_limit
					
					# Wake up waiting tasks if limit increased:
					@available.broadcast if new_limit > old_limit
				end
			end
			
			protected
			
			# Acquire resource with optional deadline.
			def acquire_resource(deadline, **options)
				# Fast path: immediate return for expired deadlines, but only if at capacity
				return nil if deadline&.expired? && @count >= @limit
				
				# Wait for capacity with deadline tracking
				while @count >= @limit
					remaining = deadline&.remaining
					return nil if remaining && remaining <= 0
					
					unless @available.wait(@mutex, remaining)
						return nil  # Timeout exceeded
					end
				end
				
				@count += 1
				
				return true
			end
			
			# Release resource.
			def release_resource(resource)
				@mutex.synchronize do
					@count -= 1
					@available.signal
				end
			end
		end
	end
end
