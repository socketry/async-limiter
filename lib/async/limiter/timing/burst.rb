# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Limiter
		module Timing
			# Provides burst control strategies for timing limiters.
			#
			# Burst strategies are stateless modules that determine whether tasks can execute
			# immediately or must wait for frame boundaries, controlling task distribution over time.
			#
			# ## Strategy Comparison
			#
			# Greedy vs Smooth behavior with 5 tasks per 60-second window:
			#
			#   Greedy Strategy (allows clustering):
			#   |█████     |█████     |█████     |█████     |
			#   0s         60s        120s       180s
			#   All 5 tasks execute immediately when window opens
			#   
			#   Smooth Strategy (enforces even distribution):
			#   |█ █ █ █ █ |█ █ █ █ █ |█ █ █ █ █ |█ █ █ █ █ |
			#   0s         60s        120s       180s
			#   Tasks spread evenly: 0s, 12s, 24s, 36s, 48s
			#
			module Burst
				# Allows tasks to cluster within windows for high-throughput scenarios.
				#
				# Greedy strategies permit multiple tasks to start immediately as long as
				# the window limit hasn't been exceeded. This creates "bursts" of activity
				# at window boundaries, maximizing throughput when resources become available.
				#
				# ## Greedy Behavior
				#
				# Greedy behavior with 3 tasks per 10-second window:
				#
				#   Window 1: [Task1, Task2, Task3] at 0s -------- (all immediate)
				#   Window 2: [Task4, Task5, Task6] at 10s ------- (all immediate)
				#
				# Perfect for: Batch processing, high-throughput scenarios
				module Greedy
					# Check if a task can be acquired in burstable mode.
					# @parameter window_count [Integer] Number of tasks started in current window.
					# @parameter limit [Integer] Maximum tasks allowed in the window.
					# @parameter frame_changed [Boolean] Ignored in burstable mode.
					# @returns [Boolean] True if under the window limit.
					def self.can_acquire?(window_count, limit, frame_changed)
						window_count < limit
					end
					
					# Calculate the next time a task can be acquired.
					# @parameter window_start_time [Numeric] When the current window started.
					# @parameter window_duration [Numeric] Duration of the window.
					# @parameter frame_start_time [Numeric] Ignored in burstable mode.
					# @parameter frame_duration [Numeric] Ignored in burstable mode.
					# @returns [Numeric] The next window start time.
					def self.next_acquire_time(window_start_time, window_duration, frame_start_time, frame_duration)
						window_start_time + window_duration
					end
					
					# Check if window constraints are blocking new tasks.
					# @parameter window_count [Integer] Number of tasks started in current window.
					# @parameter limit [Integer] Maximum tasks allowed in the window.
					# @parameter window_changed [Boolean] Whether the window has reset.
					# @returns [Boolean] True if window is blocking new tasks.
					def self.window_blocking?(window_count, limit, window_changed)
						return false if window_changed
						window_count >= limit
					end
					
					# Check if frame constraints are blocking new tasks.
					# @parameter frame_changed [Boolean] Whether the frame boundary has been crossed.
					# @returns [Boolean] Always false for burstable mode.
					def self.frame_blocking?(frame_changed)
						false  # Burstable mode doesn't use frame blocking
					end
				end
				
				# Enforces even task distribution to prevent clustering.
				#
				# Smooth strategies prevent clustering by requiring tasks to wait for
				# frame boundaries, ensuring smooth and predictable task execution timing.
				# This creates consistent load patterns and prevents resource spikes.
				#
				# ## Smooth Behavior
				#
				# Smooth behavior with 3 tasks per 15-second window:
				#
				#   Window 1: [Task1] -- [Task2] -- [Task3] ---- (evenly spaced)
				#             0s      5s      10s     15s
				#   Window 2: [Task4] -- [Task5] -- [Task6] ---- (evenly spaced)
				#             15s     20s     25s     30s
				#
				# Perfect for: API rate limiting, smooth resource usage
				module Smooth
					# Check if a task can be acquired in continuous mode.
					# @parameter window_count [Integer] Ignored in continuous mode.
					# @parameter limit [Integer] Ignored in continuous mode.
					# @parameter frame_changed [Boolean] Whether the frame boundary has been crossed.
					# @returns [Boolean] True only if the frame boundary has been crossed.
					def self.can_acquire?(window_count, limit, frame_changed)
						frame_changed
					end
					
					# Calculate the next time a task can be acquired.
					# @parameter window_start_time [Numeric] Ignored in continuous mode.
					# @parameter window_duration [Numeric] Ignored in continuous mode.
					# @parameter frame_start_time [Numeric] When the current frame started.
					# @parameter frame_duration [Numeric] Duration of each frame.
					# @returns [Numeric] The next frame start time.
					def self.next_acquire_time(window_start_time, window_duration, frame_start_time, frame_duration)
						frame_start_time + frame_duration
					end
					
					# Check if window constraints are blocking new tasks.
					# @parameter window_count [Integer] Ignored in continuous mode.
					# @parameter limit [Integer] Ignored in continuous mode.
					# @parameter window_changed [Boolean] Ignored in continuous mode.
					# @returns [Boolean] Always false for continuous mode.
					def self.window_blocking?(window_count, limit, window_changed)
						false  # Continuous mode doesn't use window blocking
					end
					
					# Check if frame constraints are blocking new tasks.
					# @parameter frame_changed [Boolean] Whether the frame boundary has been crossed.
					# @returns [Boolean] True if frame hasn't changed (blocking until next frame).
					def self.frame_blocking?(frame_changed)
						!frame_changed
					end
				end
			end
		end
	end
end
