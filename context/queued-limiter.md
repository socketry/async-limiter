# Queued Limiter

This guide explains the {ruby Async::Limiter::Queued} class, which provides priority-based task scheduling with optional resource management. Its key feature is priority-based acquisition where higher priority tasks get access first, with optional support for distributing specific resources from a pre-populated queue.

## Usage

Use a queue of specific resources that tasks can acquire:

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

# Output shows tasks sharing the 3 available connections
# Tasks 3,4 wait for connections to be returned
```

### Manual Resource Management

For fine-grained control over resource lifecycle:

```ruby
queue = Async::Queue.new
3.times { |i| queue.push("resource_#{i}") }

limiter = Async::Limiter::Queued.new(queue)

# Acquire with automatic return
limiter.acquire do |resource|
	puts "Using #{resource}"
	# Resource automatically returned when block exits
end

# Manual acquire/release pattern
resource = limiter.acquire
begin
	puts "Using #{resource}"
	# Do work with resource
ensure
	limiter.release(resource)
end
```

## Priority-Based Resource Allocation

Tasks with higher priority values get resources first:

```ruby
Async do
	queue = Async::PriorityQueue.new
	limiter = Async::Limiter::Queued.new(queue)
	results = []

	# Start tasks with different priorities
	tasks = [
		Async do
			result = limiter.acquire(priority: 1, timeout: 1.0) do |worker|
				"Low priority task used #{worker}"
			end
			results << result
		end,
		
		Async do
			result = limiter.acquire(priority: 10, timeout: 1.0) do |worker|
				"High priority task used #{worker}"
			end
			results << result
		end,
		
		Async do
			result = limiter.acquire(priority: 5, timeout: 1.0) do |worker|
				"Medium priority task used #{worker}"
			end
			results << result
		end
	]
	
	# Add some "workers":
	2.times do |i|
		limiter.release("worker_#{i}")
	end

	tasks.each(&:wait)

	puts results
	# High priority task gets resource first, then medium, then low.
end
```
