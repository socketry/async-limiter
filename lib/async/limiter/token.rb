# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

module Async
	module Limiter
		# Token that represents an acquired resource and can be used to release or re-acquire.
		#
		# Tokens provide advanced resource management by encapsulating both the acquired
		# resource and the acquisition options (timeout, cost, priority, etc.). This enables
		# re-acquisition with modified parameters while maintaining the original context.
		#
		# The token automatically tracks release state using the resource itself as the
		# state indicator (nil = released, non-nil = acquired).
		class Token
			# Acquire a token from a limiter.
			#
			# This class method provides a clean way to acquire tokens without
			# adding token-specific methods to limiter classes.
			#
			# @parameter limiter [Generic] The limiter to acquire from.
			# @parameter options [Hash] Acquisition options (timeout, cost, priority, etc.).
			# @yields {|token| ...} Optional block executed with automatic token release.
			#   @parameter token [Token] The acquired token object.
			# @returns [Token, nil] A token object, or nil if acquisition failed.
			# @raises [ArgumentError] If cost exceeds the timing strategy's maximum supported cost.
			# @asynchronous
			def self.acquire(limiter, **options, &block)
				resource = limiter.acquire(**options)
				return nil unless resource
				
				token = new(limiter, resource)
				
				return token unless block_given?
				
				begin
					yield(token)
				ensure
					token.release
				end
			end
			# Initialize a new token.
			# @parameter limiter [Generic] The limiter that issued this token.
			# @parameter resource [Object] The acquired resource.
			def initialize(limiter, resource)
				@limiter = limiter
				@resource = resource
			end
			
			# @attribute [Object] The acquired resource (nil if released).
			attr_reader :resource
			
			# Release the token back to the limiter.
			def release
				if resource = @resource
					@resource = nil
					@limiter.release(resource)
				end
			end
			
			# Re-acquire the resource with modified options.
			#
			# This allows changing acquisition parameters (timeout, cost, priority, etc.)
			# while maintaining the token context. The current resource is released
			# and a new one is acquired with the merged options.
			#
			# @parameter new_options [Hash] New acquisition options (timeout, cost, priority, etc.).
			#   These are merged with the original options, with new options taking precedence.
			# @returns [Token] A new token for the re-acquired resource.
			# @raises [ArgumentError] If the new cost exceeds timing strategy capacity.
			# @asynchronous
			def acquire(**options, &block)
				raise "Token already acquired!" if @resource
				
				@resource = @limiter.acquire(reacquire: true, **options)
				
				return @resource unless block_given?
				
				begin
					return yield(@resource)
				ensure
					self.release
				end
			end
			
			# Check if the token has been released.
			# @returns [Boolean] True if the token has been released.
			def released?
				@resource.nil?
			end
		end
	end
end
