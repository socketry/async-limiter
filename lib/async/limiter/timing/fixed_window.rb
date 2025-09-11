# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require_relative "sliding_window"

module Async
	module Limiter
		module Timing
			# Fixed window timing strategy with discrete boundaries aligned to clock time.
			#
			# Fixed windows reset at specific intervals (e.g., every minute at :00 seconds),
			# creating predictable timing patterns and allowing bursting at window boundaries.
			class FixedWindow < SlidingWindow
				# Calculate the start time of the fixed window containing the given time.
				# @parameter current_time [Numeric] The current time.
				# @returns [Numeric] The window start time aligned to window boundaries.
				def window_start_time(current_time)
					(current_time / @duration).to_i * @duration
				end
			end
		end
	end
end
