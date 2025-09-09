# Limited Limiter

This guide explains the {ruby Async::Limiter::Limited} class, which provides semaphore-style concurrency control, enforcing a maximum number of concurrent operations. It's perfect for controlling concurrency when you have limited capacity or want to prevent system overload.

## Usage

Limit the number of concurrent tasks:

```ruby
require "async"
require "async/limiter"

Async do
	# Maximum 2 concurrent tasks
	limiter = Async::Limiter::Limited.new(2)
	
	4.times do |i|
		limiter.async do |task|
			puts "Task #{i} started at #{Time.now}"
			task.sleep 1
			puts "Task #{i} finished at #{Time.now}"
		end
	end
end

# Output shows tasks 0,1 run first, then tasks 2,3
# Total duration: ~2 seconds instead of ~1 second
```

### Block-Based Acquisition

The recommended pattern using automatic cleanup:

```ruby
limiter = Async::Limiter::Limited.new(1)

# Acquire with automatic release using blocks:
limiter.acquire do |acquired|
	puts "I have acquired: #{acquired}"
	# Automatically released when block exits.
end
```

## Timeouts

All acquisition methods support comprehensive timeout options:

```ruby
limiter = Async::Limiter::Limited.new(1)

Async do
	# Non-blocking (immediate check) - should succeed:
	if limiter.acquire(timeout: 0)
		puts "Got acquisition immediately"
	else
		puts "No capacity available"
	end
	
	# Now limiter is at capacity, so subsequent calls will fail/timeout.
	
	# Non-blocking check - will fail since capacity is used:
	if limiter.acquire(timeout: 0)
		puts "Got second acquisition"
	else
		puts "No capacity available for second acquisition"
	end
	
	# Timed acquisition - will timeout since capacity is still used:
	if limiter.acquire(timeout: 0.1)
		puts "Got acquisition within timeout"
	else
		puts "Timed out waiting for capacity"
	end
	
	# With blocks (automatic cleanup):
	result = limiter.acquire(timeout: 1.0) do |acquired|
		"Successfully acquired and used"
	end
	
	puts result || "Acquisition timed out"
end
```

### Concurrent Timeout Behavior

The limiter prevents convoy effects where quick timeouts aren't blocked by slow ones:

```ruby
limiter = Async::Limiter::Limited.new(1)
Async do
	limiter.acquire  # Fill to capacity.

	results = []

	# Start multiple tasks with different timeouts:
	tasks = [
		Async {limiter.acquire(timeout: 1.0); results << "Long timeout."},
		Async {limiter.acquire(timeout: 0.1); results << "Short timeout."},
		Async {limiter.acquire(timeout: 0);   results << "Non-blocking."},
	]

	# All tasks complete quickly, even with a long timeout task present:
	tasks.map(&:wait)
	puts results
	# => ["Non-blocking.", "Short timeout.", "Long timeout."]
end
```

## Dynamic Limit Adjustment

Adjust limits at runtime based on changing conditions:

```ruby
limiter = Async::Limiter::Limited.new(2)
puts "Initial limit: #{limiter.limit}"  # 2

# Increase capacity during high load
limiter.limit = 5
puts "Increased limit: #{limiter.limit}"  # 5

# Decrease capacity during high load
limiter.limit = 1
puts "Decreased limit: #{limiter.limit}"  # 1
```

## Cost-Based Operations

Operations can consume multiple "units" based on their computational weight:

```ruby
# Create limiter with timing strategy that has capacity limits:
timing = Async::Limiter::Timing::LeakyBucket.new(5.0, 10.0)  # 5/sec rate, 10 capacity.
limiter = Async::Limiter::Limited.new(100, timing: timing)

Async do
	# Light operations (consume 0.5 units):
	limiter.acquire(cost: 0.5) do
		perform_light_database_query()
	end
	
	# Normal operations (default cost: 1.0):
	limiter.acquire do
		perform_standard_operation()
	end
	
	# Heavy operations (consume 3.5 units):
	limiter.acquire(cost: 3.5) do
		perform_heavy_computation()
	end
	
	# Operations exceeding capacity fail fast:
	begin
		# Exceeds timing capacity of 10.0:
		limiter.acquire(cost: 15.0)
	rescue ArgumentError => error
		puts "#{error.message}"
		# => Cost 15.0 exceeds maximum supported cost 10.0
	end
end
```

### Cost + Timeout Combinations

When using cost-based operations with timing strategies, be aware that high-cost operations can be starved by continuous low-cost operations. Use {ruby Async::Limiter::Timing::Ordered} to enforce FIFO ordering if fairness is important:

```ruby
# Default behavior - potential starvation:
timing = Async::Limiter::Timing::LeakyBucket.new(2.0, 10.0)
limiter = Async::Limiter::Limited.new(100, timing: timing)

# High-cost operation might be starved by many small operations:
result = limiter.acquire(timeout: 30.0, cost: 8.0) do |acquired|
	expensive_machine_learning_inference()
end

# With FIFO ordering - prevents starvation:
ordered_timing = Async::Limiter::Timing::Ordered.new(timing)
fair_limiter = Async::Limiter::Limited.new(100, timing: ordered_timing)

# High-cost operation is guaranteed to execute in arrival order:
result = fair_limiter.acquire(timeout: 30.0, cost: 8.0) do |acquired|
	expensive_machine_learning_inference()
end
```
