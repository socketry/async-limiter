# Generic Limiter

This guide explains the {ruby Async::Limiter::Generic} class, which provides unlimited concurrency by default and serves as the base implementation for all other limiters. It's ideal when you need timing constraints without concurrency limits, or when building custom limiter implementations.

## Usage

The simplest case - no limits on concurrent execution:

```ruby
require "async"
require "async/limiter"

Async do
	limiter = Async::Limiter::Generic.new
	
	# All 100 tasks run concurrently:
	100.times do |i|
		limiter.async do |task|
			puts "Task #{i} running"
			task.sleep 1
		end
	end
end
```

All tasks start immediately and run in parallel, limited only by system resources.

### Async Execution

The primary way to use Generic limiter is through the `async` method:

```ruby
require "async"
require "async/limiter"

Async do
	limiter = Async::Limiter::Generic.new

	# Create async tasks through the limiter:
	tasks = 5.times.map do |i|
		limiter.async do |task|
			puts "Task #{i} started at #{Time.now}"
			task.sleep 1
			puts "Task #{i} completed at #{Time.now}"
			"result_#{i}"
		end
	end
	
	# Wait for all tasks to complete:
	results = tasks.map(&:wait)
	puts "All results: #{results}"
end
```

### Sync Execution

For synchronous execution within an async context:

```ruby
Async do
	limiter = Async::Limiter::Generic.new
	
	# Execute synchronously within the limiter:
	result = limiter.sync do |task|
		puts "Executing in task: #{task}"
		"sync result"
	end
	
	puts result  # => "sync result"
end
```

## Timing Coordination

Generic limiters excel when combined with timing strategies for pure rate limiting:

### Rate Limiting Without Concurrency Limits

```ruby
Async do
	# Allow unlimited concurrency but rate limit to 10 operations per second:
	timing = Async::Limiter::Timing::LeakyBucket.new(10.0, 50.0)
	limiter = Async::Limiter::Generic.new(timing: timing)

	# All tasks start immediately, but timing strategy controls rate:
	100.times do |i|
		limiter.async do |task|
			puts "Task #{i} executing at #{Time.now}"
			# Timing strategy ensures rate limiting.
		end
	end
end
```

### Burst Handling

```ruby
Async do
	# Allow bursts up to 20 operations, then limit to 5 per second:
	timing = Async::Limiter::Timing::SlidingWindow.new(
		# 1-second window:
		1.0,
		# Allow bursting:
		Async::Limiter::Timing::Burst::Greedy,
		# 5 operations per second:
		5
	)
	
	limiter = Async::Limiter::Generic.new(timing: timing)
	
	# First 20 operations execute immediately (burst).
	# Subsequent operations are rate limited:
	50.times do |i|
		limiter.async do |task|
			puts "Operation #{i} at #{Time.now}"
		end
	end
end
```

## Advanced Usage Patterns

### Cost-Based Operations

When using timing strategies, you can specify different costs for operations:

```ruby
# Create limiter with timing strategy that supports costs:
timing = Async::Limiter::Timing::LeakyBucket.new(10.0, 50.0)  # 10/sec rate, 50 capacity.
limiter = Async::Limiter::Generic.new(timing: timing)

Async do
	# Light operations:
	limiter.acquire(cost: 0.5) do |resource|
		puts "Light operation using #{resource}"
	end
	
	# Standard operations (default cost: 1.0):
	limiter.acquire do |resource|
		puts "Standard operation using #{resource}"
	end
	
	# Heavy operations:
	limiter.acquire(cost: 5.0) do |resource|
		puts "Heavy operation using #{resource}"
	end
	
	# Operations that exceed timing capacity will fail:
	begin
		limiter.acquire(cost: 100.0)  # Exceeds capacity of 50.0.
	rescue ArgumentError => error
		Console.error(self, error)
	end
end
```

Note that by default, lower cost operations will occur before higher cost operations. In other words, low cost operations will starve out higher cost operations unless you use {ruby Async::Limiter::Timing::Ordered} to force FIFO acquires.

```ruby
# Default behavior - potential starvation:
timing = Async::Limiter::Timing::LeakyBucket.new(2.0, 10.0)

# FIFO ordering - prevents starvation:
timing = Async::Limiter::Timing::Ordered.new(
	Async::Limiter::Timing::LeakyBucket.new(2.0, 10.0)
)
```
