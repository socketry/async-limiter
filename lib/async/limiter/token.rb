# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Francisco Mejia.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

module Async
	module Limiter
		# Token that represents an acquired resource and can be used to release or re-acquire.
		#
		# Tokens encapsulate the acquired resource and its limiter, allowing the resource
		# to be released and re-acquired.
		#
		# The token automatically tracks release state using the resource itself as the
		# state indicator (nil = released, non-nil = acquired). A closed token also
		# clears its limiter reference, which prevents future re-acquisition.
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
			def initialize(limiter, resource = nil)
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
			
			# Close the token and prevent future re-acquisition.
			def close
				self.release
				@limiter = nil
			end
			
			# Re-acquire the resource.
			#
			# @parameter options [Hash] Acquisition options (timeout, cost, priority, etc.).
			#   Omitted options use the limiter's defaults.
			# @yields {|resource| ...} Optional block executed with automatic token release.
			#   @parameter resource [Object, nil] The acquired resource, or nil if acquisition failed.
			# @returns [Object, nil] The acquired resource, or nil if acquisition failed or the token is closed.
			#   When used with a block, returns the result of the block execution unless the token is closed.
			# @raises [RuntimeError] If the token is already acquired.
			# @raises [ArgumentError] If the new cost exceeds timing strategy capacity.
			# @asynchronous
			def acquire(**options, &block)
				raise "Token already acquired!" if @resource
				return nil unless @limiter
				
				@resource = @limiter.acquire(reacquire: true, **options)
				
				return @resource unless block_given?
				
				begin
					return yield(@resource)
				ensure
					self.release
				end
			end
			
			# Check if the token has been acquired.
			# @returns [Boolean] True if the token has been acquired.
			def acquired?
				!!@resource
			end
			
			# Check if the token has been released.
			# @returns [Boolean] True if the token has been released.
			def released?
				!@resource
			end
			
			# Check if the token has been closed.
			# @returns [Boolean] True if the token has been closed.
			def closed?
				!@limiter
			end
		end
	end
end
