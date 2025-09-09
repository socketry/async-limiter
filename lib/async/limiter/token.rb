# frozen_string_literal: true

# Released under the MIT License.
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
			# Initialize a new token.
			# @parameter limiter [Generic] The limiter that issued this token.
			# @parameter resource [Object] The acquired resource.
			# @parameter options [Hash] Options used for acquisition (timeout, cost, priority, etc.).
			def initialize(limiter, resource, **options)
				@limiter = limiter
				@resource = resource
				@options = options
			end
			
			# @attribute [Object] The acquired resource (nil if released).
			attr_reader :resource
			
			# Release the token back to the limiter.
			def release
				return unless @resource
				
				@limiter.release(@resource)
				@resource = nil
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
			def acquire(**new_options, &block)
				release  # Release current resource
				
				# Merge original options with new ones (new ones take precedence)
				merged_options = @options.merge(new_options)
				
				# Re-acquire directly and update this token's state
				@resource = @limiter.acquire(**merged_options, &block)
				@options = merged_options
				
				# Return this token (now updated) or block result
				block_given? ? @resource : self
			end
			
			# Check if the token has been released.
			# @returns [Boolean] True if the token has been released.
			def released?
				@resource.nil?
			end
		end
	end
end
