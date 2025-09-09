# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/task"
require "async/deadline"
require_relative "timing/none"
require_relative "timing/sliding_window"
require_relative "token"

module Async
	module Limiter
		# Generic limiter class with unlimited concurrency by default.
		#
		# This provides the foundation for rate limiting and concurrency control.
		# Subclasses can override methods to implement specific limiting behaviors.
		#
		# The Generic limiter coordinates timing strategies with concurrency control,
		# providing thread-safe acquisition with deadline tracking and cost-based consumption.
		class Generic
			# Initialize a new generic limiter.
			# @parameter timing [#acquire, #wait, #maximum_cost] Strategy for timing constraints.
			# @parameter parent [Async::Task, nil] Parent task for creating child tasks.
			def initialize(timing: Timing::None, parent: nil)
				@timing = timing
				@parent = parent
				
				@mutex = Mutex.new
			end
			
			def limited?
				false
			end
			
			# Execute a task asynchronously with unlimited concurrency.
			# @parameter parent [Async::Task] Parent task for the new task.
			# @parameter options [Hash] Additional options passed to {Async::Task#async}.
			# @yields {|task| ...} The block to execute within the limiter constraints.
			#   @parameter task [Async::Task] The async task context.
			# @returns [Async::Task] The created task.
			# @asynchronous
			def async(parent: (@parent || Task.current), **options)
				acquire
				parent.async(**options) do |task|
					yield task
				ensure
					release
				end
			end
			
			# Execute a task synchronously with unlimited concurrency.
			# @yields {|task| ...} The block to execute within the limiter constraints.
			#   @parameter task [Async::Task] The current task context.
			# @asynchronous
			def sync
				acquire do
					yield(Task.current)
				end
			end
			
			# Manually acquire a resource with timing and concurrency coordination.
			# 
			# This method provides the core acquisition logic with support for:
			# - Flexible timeout handling (blocking, non-blocking, timed)
			# - Cost-based consumption for timing strategies
			# - Deadline tracking to prevent timeout violations
			# - Automatic resource cleanup with block usage
			#
			# @parameter timeout [Numeric, nil] Timeout in seconds (nil = wait forever, 0 = non-blocking).
			# @parameter cost [Numeric] The cost/weight of this operation for timing strategies (default: 1).
			# @parameter options [Hash] Additional options passed to concurrency acquisition.
			# @yields {|resource| ...} Optional block executed with automatic resource release.
			#   @parameter resource [Object] The acquired resource.
			# @returns [Object, nil] The acquired resource, or nil if acquisition failed/timed out.
			#   When used with a block, returns the result of the block execution.
			# @raises [ArgumentError] If cost exceeds the timing strategy's maximum supported cost.
			# @asynchronous
			def acquire(timeout: nil, cost: 1, **options)
				# Validate cost against timing strategy capacity:
				maximum_cost = @timing.maximum_cost
				if cost > maximum_cost
					raise ArgumentError, "Cost #{cost} exceeds maximum supported cost #{maximum_cost} for timing strategy!"
				end
				
				resource = nil
				deadline = Deadline.start(timeout)
				
				# Atomically handle timing constraints and concurrency logic:
				@mutex.synchronize do
					# Wait for timing constraints to be satisfied (mutex released during sleep)
					return nil unless @timing.wait(@mutex, deadline, cost)
					
					# Execute the concurrency-specific acquisition logic
					resource = acquire_concurrency(deadline, **options)
					
					# Record timing acquisition if successful
					if resource
						@timing.acquire(cost)
					end
					
					resource
				end
				
				return resource unless block_given?
				
				begin
					yield(resource)
				ensure
					release(resource)
				end
			end
			
			# Acquire a token that encapsulates the acquired resource and acquisition options.
			#
			# Tokens provide advanced resource management with support for re-acquisition
			# using different options (priority, timeout, cost, etc.).
			#
			# @parameter timeout [Numeric, nil] Timeout in seconds (nil = wait forever, 0 = non-blocking).
			# @parameter cost [Numeric] The cost/weight of this operation for timing strategies (default: 1).
			# @parameter options [Hash] Additional options (priority, etc.) stored for re-acquisition.
			# @yields {|token| ...} Optional block executed with automatic token release.
			#   @parameter token [Token] The acquired token object.
			# @returns [Token] A token object that can release or re-acquire the resource.
			# @raises [ArgumentError] If cost exceeds the timing strategy's maximum supported cost.
			# @asynchronous
			def acquire_token(**options)
				resource = acquire(**options)
				return nil unless resource
				
				token = Token.new(self, resource, **options)
				
				return token unless block_given?
				
				begin
					yield(token)
				ensure
					token.release
				end
			end
			
			# Release a previously acquired resource.
			def release(resource = nil)
				# Default implementation - subclasses should override.
			end
			
			protected
			
			# Default concurrency acquisition for unlimited semaphore.
			# Subclasses should override this method.
			def acquire_concurrency(deadline = nil, **options)
				# Default unlimited behavior - always succeeds
				true
			end
		end
	end
end
