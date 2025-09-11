# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "metrics/provider"
require "async/clock"
require_relative "../../../../async/limiter/generic"

# Metrics provider for Async::Limiter::Generic instrumentation.
# This monkey patches the Generic limiter class to add metrics around
# acquire and release operations for observability.
Metrics::Provider(Async::Limiter::Generic) do
	ACQUIRE_COUNTER = Metrics.metric("async.limiter.acquire", :counter, description: "Number of limiter acquire operations.")
	ACQUIRE_DURATION = Metrics.metric("async.limiter.acquire.duration", :histogram, description: "Duration of limiter acquire operations.")
	ACQUIRE_ATTEMPTS = Metrics.metric("async.limiter.acquire.attempts", :counter, description: "Total number of limiter acquire attempts.")
	RELEASE_COUNTER = Metrics.metric("async.limiter.release", :counter, description: "Number of limiter release operations.")
	
	def acquire_synchronized(timeout, cost, **options)
		# Build base tags and extend with instance tags if present
		is_reacquire = options[:reacquire] || false
		tags = ["limiter:#{self.class.name}", "cost:#{cost}", "reacquire:#{is_reacquire}"]
		tags = Metrics::Tags.normalize(@tags, tags)
		
		clock = Async::Clock.start
		ACQUIRE_ATTEMPTS.emit(1, tags: tags)
		
		begin
			if result = super
				# Emit success metrics
				success_tags = Metrics::Tags.normalize(["result:success"], tags)
				ACQUIRE_COUNTER.emit(1, tags: success_tags)
				ACQUIRE_DURATION.emit(clock.total, tags: success_tags)
			else
				# Emit failure metrics (timeout/contention)
				failure_tags = Metrics::Tags.normalize(["result:timeout"], tags)
				ACQUIRE_COUNTER.emit(1, tags: failure_tags)
				ACQUIRE_DURATION.emit(clock.total, tags: failure_tags)
			end
			
			return result
		rescue => error
			# Emit error metrics
			error_tags = Metrics::Tags.normalize(["result:error", "error:#{error.class.name}"], tags)
			ACQUIRE_COUNTER.emit(1, tags: error_tags)
			ACQUIRE_DURATION.emit(clock.total, tags: error_tags)
			
			raise
		end
	end
	
	def release(resource = true)
		# Build base tags and extend with instance tags if present
		tags = ["limiter:#{self.class.name}"]
		tags = Metrics::Tags.normalize(@tags, tags)
		
		begin
			result = super
			
			# Emit success metrics
			success_tags = Metrics::Tags.normalize(["result:success"], tags)
			RELEASE_COUNTER.emit(1, tags: success_tags)
			
			result
		rescue => error
			# Emit failure metrics
			error_tags = Metrics::Tags.normalize(["result:error", "error:#{error.class.name}"], tags)
			RELEASE_COUNTER.emit(1, tags: error_tags)
			
			raise
		end
	end
end
