# Getting Started

This guide explains how to get started the `async-limiter` gem for controlling concurrency and rate limiting in Ruby applications.

## Installation

Add the gem to your project:

```bash
$ bundle add async-limiter
```

## Core Concepts

`async-limiter` provides three main limiter classes that can be combined with timing strategies:

### Limiter Classes

- **{ruby Async::Limiter::Generic}** - Unlimited concurrency (default behavior).
- **{ruby Async::Limiter::Limited}** - Enforces a concurrency limit (counting semaphore).
- **{ruby Async::Limiter::Queued}** - Queue-based limiter with priority/timeout support.

### Timing Strategies

- **{ruby Async::Limiter::Timing::None}** - No timing constraints (default).
- **{ruby Async::Limiter::Timing::SlidingWindow}** - Continuous rolling time windows.
- **{ruby Async::Limiter::Timing::FixedWindow}** - Discrete time boundaries.
- **{ruby Async::Limiter::Timing::LeakyBucket}** - Token bucket with automatic leaking.

## Basic Usage

### Unlimited Concurrency

The simplest case - no limits:

```ruby
require "async"
require "async/limiter"

Async do
	limiter = Async::Limiter::Generic.new
	
	# All tasks run concurrently:
	100.times do |i|
		limiter.async do |task|
			puts "Task #{i} running"
			task.sleep 1
		end
	end
end
```

### Concurrency Limiting

Limit the number of concurrent tasks:

```ruby
require "async"
require "async/limiter"

Async do
	# Max 2 concurrent tasks:
	limiter = Async::Limiter::Limited.new(2)
	
	4.times do |i|
		limiter.async do |task|
			puts "Task #{i} started"
			task.sleep 1
			puts "Task #{i} finished"
		end
	end
end
```

This runs a maximum of 2 tasks concurrently. Total duration is 2 seconds (tasks 0,1 run first, then tasks 2,3).

### Queue-Based Resource Management

Use a pre-populated queue of specific resources:

```ruby
require "async"
require "async/limiter"
require "async/queue"

Async do
	# Pre-populate queue with database connections
	queue = Async::Queue.new
	queue.push("connection_1")
	queue.push("connection_2") 
	queue.push("connection_3")
	
	limiter = Async::Limiter::Queued.new(queue)
	
	5.times do |i|
		limiter.async do |task|
			# Automatically gets an available connection
			limiter.acquire do |connection|
				puts "Task #{i} using #{connection}"
				task.sleep 1
				# Connection automatically returned to queue
			end
		end
	end
end
```

## Advanced Timeout Features

### Unified Timeouts

All acquisition methods support flexible timeout handling:

```ruby
limiter = Async::Limiter::Limited.new(1)

# Blocking (wait forever)
resource = limiter.acquire

# Non-blocking (immediate)
resource = limiter.acquire(timeout: 0)
return "busy" unless resource

# Timed (wait up to 2.5 seconds)
resource = limiter.acquire(timeout: 2.5)
return "timeout" unless resource

# With blocks (automatic cleanup)
limiter.acquire(timeout: 1.0) do |resource|
	# Use resource
end  # Automatically released
```


## Rate Limiting with Timing Strategies

### Sliding Window Rate Limiting

Continuous rolling time windows:

```ruby
require "async"
require "async/limiter"

Async do
	# Max 3 tasks within any 1-second sliding window
	timing = Async::Limiter::Timing::SlidingWindow.new(
		1.0,                                             # 1-second window
		Async::Limiter::Timing::BurstStrategy::Greedy,   # Allow bursting
		3                                                # 3 tasks per window
	)
	
	limiter = Async::Limiter::Limited.new(10, timing: timing)
	
	10.times do |i|
		limiter.async do |task|
			puts "Task #{i} started at #{Time.now}"
			task.sleep 0.5
		end
	end
end
```

### Fixed Window Rate Limiting

Discrete time boundaries:

```ruby
# Max 5 tasks per 2-second window with fixed boundaries
timing = Async::Limiter::Timing::FixedWindow.new(
	2.0,                                             # 2-second windows
	Async::Limiter::Timing::BurstStrategy::Greedy,   # Allow bursting
	5                                                # 5 tasks per window
)

limiter = Async::Limiter::Limited.new(10, timing: timing)
```

### Leaky Bucket Rate Limiting

Smooth rate limiting with token consumption:

```ruby
# 10 tokens per second, bucket capacity of 50 tokens
timing = Async::Limiter::Timing::LeakyBucket.new(
	10.0,  # 10 tokens/second leak rate
	50.0   # 50 token capacity
)

limiter = Async::Limiter::Limited.new(100, timing: timing)

# Bucket starts empty, fills with usage, leaks over time
```

## Cost-Based Acquisition

Operations can consume multiple "units" based on their computational weight:

```ruby
# Create a leaky bucket with 10 tokens capacity
timing = Async::Limiter::Timing::LeakyBucket.new(5.0, 10.0)  # 5/sec rate, 10 capacity
limiter = Async::Limiter::Limited.new(100, timing: timing)

# Light operations
limiter.acquire(cost: 0.5) do
	perform_light_operation()
end

# Normal operations  
limiter.acquire(cost: 1.0) do  # Default cost
	perform_standard_operation()
end

# Heavy operations
limiter.acquire(cost: 3.5) do
	perform_heavy_operation()
end

# Impossible operations fail fast
begin
	limiter.acquire(cost: 15.0)  # Exceeds capacity!
rescue ArgumentError => e
	puts "#{e.message}"  # Cost 15.0 exceeds maximum supported cost 10.0
end
```

### Cost + Timeout Combinations

```ruby
# Heavy operation with timeout
result = limiter.acquire(timeout: 30.0, cost: 5.0) do |resource|
	expensive_computation()
end

if result
	puts "Completed successfully"
else
	puts "Timed out waiting for capacity"
end
```

## Token-Based Resource Management

For advanced resource management with re-acquisition support:

```ruby
# Acquire a token that can be reused
token = limiter.acquire_token(priority: 10)

use_resource(token.resource)

# Re-acquire with different priority
new_token = token.acquire(priority: 5)
use_resource(new_token.resource)

# Manual cleanup
token.release

# Or with blocks (automatic cleanup)
limiter.acquire_token do |token|
	use_resource(token.resource)
	
	# Re-acquire within the same block
	token.acquire(priority: 1) do |new_token|
		use_resource_again(new_token.resource)
	end
end  # All tokens automatically released
```

## Manual Resource Management

You can manually acquire and release resources:

```ruby
limiter = Async::Limiter::Limited.new(1)

# Acquire with automatic release
limiter.acquire do |resource|
	puts "I have the resource"
	# Automatically released when block exits
end

# Manual acquire/release
resource = limiter.acquire
begin
	puts "I have the resource"
ensure
	limiter.release(resource)
end

# Non-blocking acquisition
resource = limiter.acquire(timeout: 0)
if resource
	begin
		puts "Got the resource immediately"
	ensure
		limiter.release(resource)
	end
else
	puts "Resource not available"
end
```

## Choosing the Right Limiter

### Use {Async::Limiter::Generic} when:
- You want unlimited concurrency
- You need timing constraints without concurrency limits
- You're building a base class for custom limiters

### Use {Async::Limiter::Limited} when:
- You need to limit concurrent execution
- You want traditional semaphore behavior
- You need timing + concurrency coordination

### Use {Async::Limiter::Queued} when:
- You have a pre-existing set of resources to distribute (DB connections, API keys, etc.).
- You need priority-based resource allocation.
- You want queue-based resource distribution with timeout support.

### Timing Strategy Selection

- **None**: Pure concurrency control without rate limiting.
- **SlidingWindow**: Smooth, continuous rate limiting.
- **FixedWindow**: Discrete time periods with burst tolerance.
- **LeakyBucket**: Token-based rate limiting with natural decay.
