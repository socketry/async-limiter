#!/usr/bin/env ruby
# frozen_string_literal: true

require "async"
require "async/limiter"

puts "=== Testing Cost Allocation Sequentialization ==="

# Create a leaky bucket with limited capacity to test cost allocation
timing = Async::Limiter::Timing::LeakyBucket.new(2.0, 10.0)  # 2 tokens/sec, capacity 10

# Enforce ordering - disable to show high-cost tasks being starved by low-cost tasks.
timing = Async::Limiter::Timing::Ordered.new(timing)

limiter = Async::Limiter::Limited.new(100, timing: timing)  # High concurrency, low timing capacity

# Fill the bucket to capacity first
10.times {limiter.acquire(cost: 1.0)}

puts "Bucket filled to capacity (10.0). Starting test..."

Async do
	results = []
	start_time = Time.now
	
	# Start a high-cost task first
	high_cost_tasks = 1.times.map do |i|
		Async do
			puts "High-cost task (cost: 8.0) starting at #{(Time.now - start_time).round(3)}s"
			result = limiter.acquire(timeout: 10.0, cost: 8.0) do |acquired|
				completion_time = (Time.now - start_time).round(3)
				puts "High-cost task completed at #{completion_time}s"
				"High-cost completed"
			end
			results << result if result
		end
	end
	
	# Wait a moment, then flood with small-cost tasks
	sleep(0.1)
	
	small_cost_tasks = 20.times.map do |i|
		Async do
			puts "Small-cost task #{i} (cost: 0.5) starting at #{(Time.now - start_time).round(3)}s"
			result = limiter.acquire(cost: 0.5) do |acquired|
				completion_time = (Time.now - start_time).round(3)
				puts "Small-cost task #{i} completed at #{completion_time}s"
				"Small-cost #{i} completed"
			end
			results << result if result
		end
	end
	
	# Wait for all tasks to complete or timeout
	all_tasks = high_cost_tasks + small_cost_tasks
	puts "Waiting for all tasks to complete... #{all_tasks.size}"
	all_tasks.map(&:wait)
	
	puts "\n=== Results ==="
	puts "Total completed tasks: #{results.size}"
	puts "Results: #{results}"
end
