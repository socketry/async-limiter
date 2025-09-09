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
		Async::Limiter::Timing::BurstStrategy::Greedy, # Allow bursting
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
