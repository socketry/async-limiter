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

## Usage

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

### Timeouts

You can control how long to wait when acquiring resources using the `timeout` parameter. This is particularly useful when working with limited capacity limiters that might block indefinitely.

```ruby
require "async"
require "async/limiter"

Async do
	# Zero limit will always block:
	limiter = Async::Limiter::Limited.new(0)
	
	limiter.acquire(timeout: 3)
	# => nil

	limiter.acquire(timeout: 3) do
		puts "Acquired."
	end or puts "Timed out!"
end
```

**Key timeout behaviors:**

- `timeout: nil` (default) - Wait indefinitely until a resource becomes available
- `timeout: 0` - Non-blocking operation; return immediately if no resource is available  
- `timeout: N` (where N > 0) - Wait up to N seconds for a resource to become available

**Return values:**
- Returns `true` (or the acquired resource) when successful
- Returns `nil` when the timeout is exceeded or no resource is available

## Rate Limiting

Timing strategies can be used to implement rate limiting, for example a continuous rolling time windows:

```ruby
require "async"
require "async/limiter"

Async do
	# Max 3 tasks within any 1-second sliding window
	timing = Async::Limiter::Timing::SlidingWindow.new(
		1.0, # 1-second window.
		Async::Limiter::Timing::Burst::Greedy, # Allow bursting
		3 # 3 tasks per window
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

### Variable Cost Operations

Rate limiting by default works with unit costs - each acquire consumes 1 unit of capacity. However, in more complex situations, you may want to use variable costs to model different operation weights:

```ruby
require "async"
require "async/limiter"

Async do
	# Leaky bucket: 2 tokens/second, capacity 10
	timing = Async::Limiter::Timing::LeakyBucket.new(2.0, 10.0)
	limiter = Async::Limiter::Limited.new(100, timing: timing)
	
	# Light operations consume fewer tokens:
	limiter.acquire(cost: 0.5) do
		puts "Light database query"
	end
	
	# Heavy operations consume more tokens:
	limiter.acquire(cost: 5.0) do
		puts "Complex ML inference"
	end
end
```

**Cost represents the resource weight** of each operation:
- `cost: 0.5` - Light operations (quick queries, cache reads).
- `cost: 1.0` - Standard operations (default).
- `cost: 5.0` - Heavy operations (complex computations, large uploads).

#### Starvation and Head-of-Line Blocking

**Variable costs introduce two important fairness issues:**

**1. Starvation Problem:**
High-cost operations can be indefinitely delayed by streams of low-cost operations:

```ruby
# Without ordering - starvation can occur
timing = Async::Limiter::Timing::LeakyBucket.new(2.0, 10.0)
limiter = Async::Limiter::Limited.new(100, timing: timing)

# High-cost task starts waiting for 8.0 tokens
limiter.acquire(cost: 8.0) do
	puts "Expensive operation"  # May never execute!
end

# Continuous stream of small operations consume tokens as they become available
100.times do |i|
	limiter.acquire(cost: 0.5) do
		puts "Quick operation #{i}"  # These keep running
	end
end
```

**2. Head-of-Line Blocking:**
When using FIFO ordering to prevent starvation, large operations can block smaller ones:

```ruby
# With ordering - prevents starvation but creates head-of-line blocking
ordered_timing = Async::Limiter::Timing::Ordered.new(timing)
fair_limiter = Async::Limiter::Limited.new(100, timing: ordered_timing)

# Large operation blocks the queue
fair_limiter.acquire(cost: 8.0) do
	puts "Expensive operation (takes time to get tokens)"
end

# These must wait even though they need fewer tokens
fair_limiter.acquire(cost: 0.5) { puts "Quick op 1" }  # Blocked
fair_limiter.acquire(cost: 0.5) { puts "Quick op 2" }  # Blocked
```

#### Choosing the Right Strategy

**Use Unordered (default) when:**
- Maximum throughput is critical
- Operations have similar costs
- Occasional starvation is acceptable

**Use Ordered when:**
- Fairness is more important than efficiency
- Starvation would be unacceptable
- Predictable execution order is required

```ruby
# Unordered: Higher throughput, possible starvation
timing = Async::Limiter::Timing::LeakyBucket.new(2.0, 10.0)

# Ordered: Fair execution, lower throughput
ordered_timing = Async::Limiter::Timing::Ordered.new(timing)
```

The choice depends on whether your application prioritizes **efficiency** (unordered) or **fairness** (ordered).
