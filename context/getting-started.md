# Getting Started

This guide explains how to get started with `async-limiter` for controlling concurrency and rate limiting in Ruby applications.

## Installation

Add the gem to your project:

```bash
$ bundle add async-limiter
```

## Core Concepts

`async-limiter` provides several types of limiters for different use cases:

- A {ruby Async::Limiter::Concurrent} which limits the number of concurrent tasks running at the same time.
- A {ruby Async::Limiter::Unlimited} which provides unlimited concurrency with tracking.
- A {ruby Async::Limiter::Window::Fixed} which combines concurrency limiting with fixed time windows.
- A {ruby Async::Limiter::Window::Sliding} which provides sliding time window limiting.
- A {ruby Async::Limiter::Window::Continuous} which provides frame-based rate limiting without bursting.

All limiters share the same interface, making them interchangeable based on your requirements.

## Basic Usage

### Concurrent Limiting

The most common use case is limiting concurrent execution:

```ruby
require "async"
require "async/limiter/concurrent"

Async do
  limiter = Async::Limiter::Concurrent.new(2)

  4.times do |i|
    limiter.async do |task|
      puts "Task #{i} started"
      task.sleep 1
      puts "Task #{i} finished"
    end
  end
end
```

This runs a maximum of 2 tasks concurrently. The total duration is 2 seconds (tasks 0,1 run first, then tasks 2,3).

### Unlimited Execution with Tracking

For scenarios where you want tracking without limiting:

```ruby
require "async"
require "async/limiter/unlimited"

Async do
  limiter = Async::Limiter::Unlimited.new

  100.times do |i|
    limiter.async do |task|
      # All tasks run concurrently
      puts "Current active tasks: #{limiter.count}"
    end
  end
end
```

### Manual Resource Management

You can also manually acquire and release resources:

```ruby
limiter = Async::Limiter::Concurrent.new(1)

# Acquire with automatic release
limiter.acquire do
  puts "I have the lock"
  # Automatically released when block exits
end

# Manual acquire/release
limiter.acquire
begin
  puts "I have the lock"
ensure
  limiter.release
end
```

## Time Window Limiting

### Fixed Windows

Limit both concurrency AND rate over discrete time periods:

```ruby
require "async"
require "async/limiter/window/fixed"

Async do
  # Max 2 concurrent, max 2 new tasks per 2-second window
  limiter = Async::Limiter::Window::Fixed.new(2, window: 2)

  6.times do |i|
    limiter.async do |task|
      puts "Task #{i} started at #{Time.now}"
      task.sleep 1
    end
  end
end
```

The output shows tasks starting in groups based on the 2-second window boundaries.

### Sliding Windows

Use continuous rolling time windows:

```ruby
require "async"
require "async/limiter/window/sliding"

Async do
  # Max 3 tasks can start within any 1-second sliding window
  limiter = Async::Limiter::Window::Sliding.new(3, window: 1)

  10.times do |i|
    limiter.async do |task|
      puts "Task #{i} started"
      task.sleep 0.5
    end
  end
end
```

### Continuous Rate Limiting

For smooth, non-burstable rate limiting:

```ruby
require "async"
require "async/limiter/window/continuous"

Async do
  # Enforces exactly 1 task per second (no bursting)
  limiter = Async::Limiter::Window::Continuous.new(1, window: 1)

  5.times do |i|
    limiter.async do |task|
      puts "Task #{i} at #{Time.now}"
    end
  end
end
```

## Advanced Features

### Custom Queues

You can provide custom queuing strategies:

```ruby
class PriorityQueue
  def push(item, priority)
    # Custom priority logic
  end
  
  def shift
    # Return highest priority item
  end
end

limiter = Async::Limiter::Concurrent.new(2, queue: PriorityQueue.new)

limiter.async(priority: :high) do |task|
  # This task gets higher priority
end
```

### Checking Limiter Status

All limiters provide status information:

```ruby
limiter = Async::Limiter::Concurrent.new(2)

puts limiter.limit     # => 2
puts limiter.count     # => 0 (current active tasks)
puts limiter.blocking? # => false (can acquire more resources)

2.times { limiter.acquire }
puts limiter.blocking? # => true (at capacity)
```

### Dynamic Limit Adjustment

Limits can be changed at runtime:

```ruby
limiter = Async::Limiter::Concurrent.new(1)
puts limiter.limit  # => 1

limiter.limit = 5
puts limiter.limit  # => 5 (existing waiting tasks are notified)
```

## Choosing the Right Limiter

### Use {Async::Limiter::Concurrent} when:
- You need to limit concurrent execution
- Task duration varies significantly
- You want simple concurrency control without time constraints

### Use {Async::Limiter::Window::Fixed} when:
- You need rate limiting over specific time periods
- You can tolerate bursting within windows
- You need both concurrency AND rate limiting

### Use {Async::Limiter::Window::Sliding} when:
- You need smooth rate limiting
- You want continuous rather than discrete time windows
- Bursting is acceptable

### Use {Async::Limiter::Window::Continuous} when:
- You need strict rate limiting without bursting
- You want evenly distributed task execution
- Consistent timing is more important than throughput

### Use {Async::Limiter::Unlimited} when:
- You want to track task execution without limiting
- You're gradually migrating from unlimited to limited execution
- You need a null object pattern for limiters

## Best Practices

1. **Choose appropriate limits**: Start with conservative limits and adjust based on monitoring
2. **Handle errors gracefully**: Use `ensure` blocks or block-form acquire to guarantee resource cleanup
3. **Monitor limiter status**: Check `blocking?` and `count` for observability  
4. **Test with realistic workloads**: Window limiters behave differently under various time pressures
5. **Consider parent tasks**: Use the `parent:` parameter to structure task hierarchies properly

## Common Patterns

### Retry with Backoff

```ruby
def with_retry(limiter, max_attempts: 3)
  attempts = 0
  
  begin
    limiter.acquire do
      yield
    end
  rescue => error
    attempts += 1
    if attempts < max_attempts
      sleep(attempts * 0.1)  # Simple backoff
      retry
    else
      raise
    end
  end
end
```

### Adaptive Limiting

```ruby
class AdaptiveLimiter
  def initialize(initial_limit)
    @limiter = Async::Limiter::Concurrent.new(initial_limit)
    @error_rate = 0.0
  end
  
  def async(&block)
    @limiter.async do |task|
      begin
        yield(task)
        adjust_limit(:success)
      rescue => error
        adjust_limit(:failure)
        raise
      end
    end
  end
  
  private
  
  def adjust_limit(outcome)
    # Increase limit on success, decrease on failure
    case outcome
    when :success
      @limiter.limit += 1 if @error_rate < 0.01
    when :failure
      @limiter.limit = [@limiter.limit - 1, 1].max
    end
  end
end
```

### Hierarchical Limiting

```ruby
# Global rate limiter
global_limiter = Async::Limiter::Window::Fixed.new(100, window: 60)

# Per-user concurrent limiter  
user_limiter = Async::Limiter::Concurrent.new(5)

# Compose limiters
global_limiter.async do
  user_limiter.async do |task|
    # This task is limited by both global rate AND user concurrency
    perform_user_action(task)
  end
end
```

This guide provides the foundation for using `async-limiter` effectively in your Ruby applications.
