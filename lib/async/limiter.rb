# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2025, by Samuel Williams.

require_relative "limiter/timing/none"
require_relative "limiter/timing/sliding_window"
require_relative "limiter/timing/fixed_window"
require_relative "limiter/timing/leaky_bucket"
require_relative "limiter/timing/burst_strategy"
require_relative "limiter/timing/ordered"
require_relative "limiter/generic"
require_relative "limiter/limited"
require_relative "limiter/token"
require_relative "limiter/queued"

# @namespace
module Async
	# @namespace
	module Limiter
	end
end
