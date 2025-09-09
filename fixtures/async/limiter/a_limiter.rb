# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter/timing/leaky_bucket"
require "sus/fixtures/async/scheduler_context"

module Async
	module Limiter
		ALimiter = Sus::Shared("a limiter") do
			let(:limiter) {subject.new}
			
			it "can acquire" do
				expect(limiter).not.to be(:limited?)
				expect(limiter.acquire).to be == true
			end
			
			it "can acquire with a block" do
				result = limiter.acquire do
					true
				end
				
				expect(result).to be == true
			end
			
			it "can acquire with a block and timeout" do
				result = limiter.acquire(timeout: 0.01) do
					true
				end
				
				expect(result).to be == true
			end
			
			it "can acquire with a block and cost" do
				result = limiter.acquire(cost: 1) do
					true
				end
				
				expect(result).to be == true
			end
			
			it "supports non-blocking acquire" do
				# Non-blocking (timeout: 0) should work for all limiters
				result = limiter.acquire(timeout: 0)
				expect(result).to be_truthy
			end
			
			it "supports non-blocking acquire with block" do
				result = limiter.acquire(timeout: 0) do
					"non-blocking result"
				end
				
				expect(result).to be == "non-blocking result"
			end
			
			it "supports timeout parameter" do
				# Basic timeout functionality should work for all limiters
				result = limiter.acquire(timeout: 0.01)
				expect(result).to be_truthy
			end
			
			with "concurrency" do
				include Sus::Fixtures::Async::SchedulerContext
				
				with Async::Limiter::Timing::SlidingWindow do
					let(:timing) {Async::Limiter::Timing::SlidingWindow.new(0.1, Async::Limiter::Timing::BurstStrategy::Greedy, 10)}
					let(:limiter) {subject.new(timing: timing)}
					
					it "can acquire several times" do
						# Consume all available capacity:
						limiter.acquire(cost: 10)
						
						tasks = 3.times.map do
							Async do
								limiter.acquire(cost: 10) do
									true
								end
							end
						end
						
						limiter.release
						
						# Verify that all tasks acquired:
						tasks.each do |task|
							expect(task.wait).to be == true
						end
					end
				end
				
				with Async::Limiter::Timing::LeakyBucket do
					# 2 tokens/sec, capacity 10
					let(:timing) {Async::Limiter::Timing::LeakyBucket.new(10.0, 10.0)}
					let(:limiter) {subject.new(timing: timing)}
					
					it "can acquire several times" do
						# Consume all available capacity:
						limiter.acquire(cost: 10)
						
						tasks = 3.times.map do
							Async do
								limiter.acquire do
									true
								end
							end
						end
						
						limiter.release
						
						# Verify that all tasks acquired:
						tasks.each do |task|
							expect(task.wait).to be == true
						end
					end
				end
			end
		end
	end
end
