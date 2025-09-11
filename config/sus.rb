# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "covered/sus"
include Covered::Sus

# ENV["TRACES_BACKEND"] ||= "traces/backend/test"
require "traces"

# ENV["METRICS_BACKEND"] ||= "metrics/backend/test"
require "metrics"
