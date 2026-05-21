# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "async/limiter"

describe Async::Limiter::Token do
	let(:limiter) {Async::Limiter::Generic.new}
	
	it "reports whether it has acquired a resource" do
		token = Async::Limiter::Token.acquire(limiter)
		
		expect(token).to be(:acquired?)
		expect(token).not.to be(:released?)
		
		token.release
		
		expect(token).not.to be(:acquired?)
		expect(token).to be(:released?)
	end
end
