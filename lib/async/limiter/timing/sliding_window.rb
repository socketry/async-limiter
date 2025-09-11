# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "async/clock"
require_relative "burst"

module Async
	module Limiter
		module Timing
			# Sliding window timing strategy with rolling time periods.
			#
			# This strategy enforces rate limiting with a rolling window that slides continuously,
			# providing smoother rate limiting than fixed windows.
			class SlidingWindow
				# @attribute [Numeric] Maximum tasks allowed per window.
				attr_reader :limit
				
				# @attribute [Numeric] Duration of the timing window in seconds.
				attr_reader :duration
				
				# Initialize a window timing strategy.
				# @parameter duration [Numeric] Duration of the window in seconds.
				# @parameter burst [#can_acquire?] Controls bursting vs smooth behavior.
				# @parameter limit [Integer] Maximum tasks per window.
				def initialize(duration, burst, limit)
					raise ArgumentError, "duration must be positive" unless duration.positive?
					
					@duration = duration
					@burst = burst
					@limit = limit
					
					@start_time = nil
					@count = 0
					@frame_start_time = nil
				end
				
				# Maximum cost this timing strategy can support.
				# @returns [Numeric] The maximum cost (equal to limit).
				def maximum_cost
					@limit
				end
				
				# Check if a task can be acquired based on window constraints.
				# @parameter cost [Numeric] The cost/weight of the operation.
				# @parameter current_time [Numeric] Current time for window calculations.
				# @returns [Boolean] True if window and frame constraints allow acquisition.
				def can_acquire?(cost = 1, current_time = Clock.now)
					# Update window if needed
					if window_changed?(current_time, @start_time)
						@start_time = window_start_time(current_time)
						@count = 0
					end
					
					frame_changed = frame_changed?(current_time)
					
					# Check both window and frame constraints with cost
					@burst.can_acquire?(@count + cost - 1, @limit, frame_changed)
				end
				
				# Record that a task was acquired.
				# @parameter cost [Numeric] The cost/weight of the operation.
				def acquire(cost = 1)
					@count += cost
					@frame_start_time = Clock.now
				end
				
				# Wait for timing constraints to be satisfied.
				# Sleeps until the next window or frame becomes available, or returns immediately if ready.
				# @parameter mutex [Mutex] Mutex to release during sleep.
				# @parameter deadline [Deadline, nil] Deadline for timeout (nil = wait forever).
				# @parameter cost [Numeric] Cost of the operation (default: 1).
				# @returns [Boolean] True if constraints are satisfied, false if timeout exceeded.
				def wait(mutex, deadline = nil, cost = 1)
					# Only wait if we can't acquire right now:
					until can_acquire?(cost, Clock.now)
						# Handle non-blocking case
						if deadline&.expired? || (deadline && deadline.remaining == 0)
							return false
						end
						
						next_time = @burst.next_acquire_time(
							@start_time,
							@duration,
							@frame_start_time,
							@duration / @limit.to_f
						)
						
						current_time = Clock.now
						wait_time = next_time - current_time
						
						return true if wait_time <= 0
						
						# Check if wait would exceed deadline
						remaining = deadline&.remaining
						if remaining && wait_time > remaining
							return false  # Would exceed deadline
						end
						
						# Wait for the required time (or remaining time if deadline specified)
						actual_wait = remaining ? [wait_time, remaining].min : wait_time
						
						mutex.sleep(actual_wait)  # Release mutex during sleep
					end
					
					return true
				end
				
				# Calculate the start time of the current window for the given time.
				# Default implementation provides sliding window behavior.
				# @parameter current_time [Numeric] The current time.
				# @returns [Numeric] The window start time (current time for sliding).
				def window_start_time(current_time)
					current_time  # Sliding window: always starts now
				end
				
				# Check if the window has changed since the last window start.
				# @parameter current_time [Numeric] The current time.
				# @parameter last_window_start [Numeric] The previous window start time.
				# @returns [Boolean] True if a new window period has begun.
				def window_changed?(current_time, last_window_start)
					return true if last_window_start.nil?
					last_window_start + @duration <= current_time
				end
				
				private
				
				def frame_changed?(current_time)
					return true if @frame_start_time.nil?
					
					frame_duration = @duration / @limit.to_f
					@frame_start_time + frame_duration <= current_time
				end
			end
		end
	end
end
