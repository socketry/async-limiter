# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2025-2026, by Shopify Inc.
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
			# @parameter options [Hash] Options passed to {Generic#initialize}.
			# @raises [ArgumentError] If limit is not positive.
			def initialize(limit = 1, **options)
				super(**options)
				
				@limit = limit
				@count = 0
				
				@available = ConditionVariable.new
				
				@acquired_count_metric = @utilization.metric(:acquired_count)
				@available_count_metric = @utilization.metric(:available_count)
				@waiting_count_metric = @utilization.metric(:waiting_count)
				@reacquire_waiting_count_metric = @utilization.metric(:reacquire_waiting_count)
				
				update_utilization_metrics
			end
			
			# @attribute [Integer] The maximum number of concurrent tasks.
			attr_reader :limit
			
			# @attribute [Integer] Current count of active tasks.
			attr_reader :count
			
			# @returns [Integer] Current count of active tasks.
			def acquired_count
				@mutex.synchronize{@count}
			end
			
			# @returns [Integer] Current count of available capacity.
			def available_count
				@mutex.synchronize{@limit - @count}
			end
			
			# @returns [Integer] Current count of tasks waiting for capacity.
			def waiting_count
				@waiting_count_metric.value
			end
			
			# @returns [Integer] Current count of reacquiring tasks waiting for capacity.
			def reacquire_waiting_count
				@reacquire_waiting_count_metric.value
			end
			
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
					update_utilization_metrics
					
					# Wake up waiting tasks if limit increased:
					@available.broadcast if new_limit > old_limit
				end
			end
			
			# Get current limiter statistics.
			# @returns [Hash] Statistics hash with current state.
			def statistics
				@mutex.synchronize do
					{
						limit: @limit,
						count: @count,
						acquired_count: @count,
						available_count: @limit - @count,
						waiting_count: @waiting_count_metric.value,
						reacquire_waiting_count: @reacquire_waiting_count_metric.value,
						timing: @timing.statistics
					}
				end
			end
			
			protected
			
			# Acquire resource with optional deadline.
			def acquire_resource(deadline, reacquire: false, **options)
				# Fast path: immediate return for expired deadlines, but only if at capacity
				return nil if deadline&.expired? && @count >= @limit
				
				waiting = false
				acquired = false
				
				# Wait for capacity with deadline tracking
				while @count >= @limit
					remaining = deadline&.remaining
					return nil if remaining && remaining <= 0
					
					unless waiting
						@waiting_count_metric.increment
						@reacquire_waiting_count_metric.increment if reacquire
						waiting = true
					end
					
					unless @available.wait(@mutex, remaining)
						return nil  # Timeout exceeded
					end
				end
				
				@count += 1
				acquired = true
				
				return true
			ensure
				if waiting
					@waiting_count_metric.decrement
					@reacquire_waiting_count_metric.decrement if reacquire
				end
				
				update_utilization_metrics if acquired
			end
			
			# Release resource.
			def release_resource(resource)
				@mutex.synchronize do
					@count -= 1
					update_utilization_metrics
					@available.signal
				end
			end
			
			private
			
			def update_utilization_metrics
				@acquired_count_metric.set(@count)
				@available_count_metric.set(@limit - @count)
			end
		end
	end
end
