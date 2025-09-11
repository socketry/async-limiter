# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "traces/provider"
require_relative "../../../../async/limiter/generic"

# Traces provider for Async::Limiter::Generic instrumentation.
# This monkey patches the Generic limiter class to add tracing around
# acquire and release operations for observability.
Traces::Provider(Async::Limiter::Generic) do
	def acquire_synchronized(timeout, cost, **options)
		attributes = {
			"limiter" => self.class.name,
			"cost" => cost,
			"timeout" => timeout,
			"priority" => options[:priority],
			"reacquire" => options[:reacquire] || false,
		}
		
		attributes.merge!(@tags) if @tags
		
		Traces.trace("async.limiter.acquire", attributes: attributes) do
			super
		end
	end
	
	def release(resource = true)
		attributes = {
			"limiter.class" => self.class.name,
		}
		
		attributes.merge!(@tags) if @tags
		
		Traces.trace("async.limiter.release", attributes: attributes) do
			super
		end
	end
end
