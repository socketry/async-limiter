# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "async/limiter"

describe Async::Limiter::Token do
	let(:limiter) {Async::Limiter::Limited.new(1)}
	
	it "reports whether it has acquired a resource" do
		token = Async::Limiter::Token.acquire(limiter)
		
		expect(token).to be(:acquired?)
		expect(token).not.to be(:released?)
		
		token.release
		
		expect(token).not.to be(:acquired?)
		expect(token).to be(:released?)
	end
	
	it "can be reacquired after release" do
		token = Async::Limiter::Token.acquire(limiter)
		
		token.release
		expect(token).to be(:released?)
		expect(limiter.available_count).to be == 1
		
		expect(token.acquire).to be == true
		expect(token).to be(:acquired?)
		expect(limiter.available_count).to be == 0
	end
	
	it "closes and releases an acquired resource" do
		token = Async::Limiter::Token.acquire(limiter)
		
		token.close
		
		expect(token).to be(:closed?)
		expect(token).to be(:released?)
		expect(limiter.available_count).to be == 1
	end
	
	it "cannot be reacquired after close" do
		token = Async::Limiter::Token.acquire(limiter)
		
		token.release
		token.close
		
		expect(token.acquire).to be_nil
		expect(token).to be(:closed?)
		expect(token).to be(:released?)
		expect(limiter.available_count).to be == 1
	end
end
