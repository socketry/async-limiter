# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Francisco Mejia.
# Copyright, 2025-2026, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require_relative "generic"
require_relative "token"

module Async
	module Limiter
		# Queue-based limiter that distributes pre-existing resources with priority/timeout support.
		#
		# This limiter manages a finite set of resources (connections, API keys, etc.)
		# that are pre-populated in a queue. It provides priority-based allocation
		# and timeout support for resource acquisition.
		#
		# Unlike Limited which counts abstract permits, Queued distributes actual
		# resource objects and supports priority queues for fair allocation.
		class Queued < Generic
			# @returns [Queue] A default queue with a single true value.
			def self.default_queue
				Queue.new.tap do |queue|
					queue.push(true)
				end
			end
			
			# Initialize a queue-based limiter.
			# @parameter queue [#push, #pop, #empty?] Thread-safe queue containing pre-existing resources.
			# @parameter options [Hash] Options passed to {Generic#initialize}.
			def initialize(queue = self.class.default_queue, **options)
				super(**options)
				@queue = queue
				
				@acquired_count_metric = @utilization.metric(:acquired_count)
				@available_count_metric = @utilization.metric(:available_count)
				@waiting_count_metric = @utilization.metric(:waiting_count)
				@reacquire_waiting_count_metric = @utilization.metric(:reacquire_waiting_count)
				
				update_utilization_metrics
			end
			
			# @attribute [Queue] The queue managing resources.
			attr_reader :queue
			
			# @returns [Integer] Current count of acquired resources.
			def acquired_count
				@acquired_count_metric.value
			end
			
			# @returns [Integer] Current count of available resources.
			def available_count
				@queue.size
			end
			
			# @returns [Integer] Current count of tasks waiting for resources.
			def waiting_count
				@queue.waiting_count
			end
			
			# @returns [Integer] Current count of reacquiring tasks waiting for resources.
			def reacquire_waiting_count
				@reacquire_waiting_count_metric.value
			end
			
			# Check if a new task can be acquired.
			# @returns [Boolean] True if resources are available.
			def limited?
				@queue.empty?
			end
			
			# Expand the queue with additional resources.
			# @parameter count [Integer] Number of resources to add.
			# @parameter value [Object] The value to add to the queue.
			def expand(count, value = true)
				count.times do
					@queue.push(value)
				end
				
				update_utilization_metrics
			end
			
			# Get current limiter statistics.
			# @returns [Hash] Statistics hash with current state.
			def statistics
				@mutex.synchronize do
					{
						waiting: @queue.waiting_count,
						available: @queue.size,
						acquired_count: @acquired_count_metric.value,
						available_count: @queue.size,
						waiting_count: @queue.waiting_count,
						reacquire_waiting_count: @reacquire_waiting_count_metric.value,
						timing: @timing.statistics
					}
				end
			end
			
			protected
			
			# Acquire a resource from the queue with optional deadline.
			def acquire_resource(deadline, reacquire: false, **options)
				@reacquire_waiting_count_metric.increment if reacquire
				update_utilization_metrics if reacquire
				
				@mutex.unlock
				resource = @queue.pop(timeout: deadline&.remaining, **options)
				return resource
			ensure
				@mutex.lock
				@reacquire_waiting_count_metric.decrement if reacquire
				@acquired_count_metric.increment if resource
				update_utilization_metrics if reacquire || resource
			end
			
			# Release a previously acquired resource back to the queue.
			def release_resource(value)
				@mutex.synchronize do
					@acquired_count_metric.decrement if @acquired_count_metric.value > 0
					update_utilization_metrics
				end
				
				# Return a default resource to the queue:
				@queue.push(value)
				update_utilization_metrics
			end
			
			private
			
			def update_utilization_metrics
				@available_count_metric.set(@queue.size)
				@waiting_count_metric.set(@queue.waiting_count)
			end
		end
	end
end
