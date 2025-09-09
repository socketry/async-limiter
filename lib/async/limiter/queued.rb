# frozen_string_literal: true

# Released under the MIT License.
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
			# Initialize a queue-based limiter.
			# @parameter queue [#push, #pop, #empty?] Thread-safe queue containing pre-existing resources.
			# @parameter timing [#can_acquire?, #acquire, #wait, #maximum_cost] Strategy for timing constraints.
			# @parameter parent [Async::Task, nil] Parent task for creating child tasks.
			def initialize(queue = Queue.new, timing: Timing::None, parent: nil)
				super(timing: timing, parent: parent)
				@queue = queue
			end
			
			# @attribute [Queue] The queue managing resources.
			attr_reader :queue
			
			# Check if a new task can be acquired.
			# @returns [Boolean] True if resources are available.
			def can_acquire?
				!@queue.empty?
			end
			
			# Expand the queue with additional resources.
			# @parameter count [Integer] Number of resources to add.
			# @parameter value [Object] The value to add to the queue.
			def expand(count, value = true)
				count.times do
					@queue.push(value)
				end
			end
			
			# Release a previously acquired resource.
			def release(value = true)
				# Return a default resource to the queue
				@queue.push(value)
			end
			
			protected
			
			# Acquire a resource from the queue with optional deadline.
			def acquire_concurrency(deadline = nil, **options)
				@queue.pop(timeout: deadline&.remaining, **options)
			end
		end
	end
end
