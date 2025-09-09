# Timing Strategies

This guide explains how to use timing strategies to provide rate limiting and timing constraints that can be combined with any limiter. They control *when* operations can execute, while limiters control *how many* can execute concurrently.

## Available Strategies

- **{ruby Async::Limiter::Timing::None}** - No timing constraints (default)
- **{ruby Async::Limiter::Timing::SlidingWindow}** - Continuous rolling time windows
- **{ruby Async::Limiter::Timing::FixedWindow}** - Discrete time boundaries
- **{ruby Async::Limiter::Timing::LeakyBucket}** - Token bucket with automatic leaking

## None Strategy

The default strategy that imposes no timing constraints:

```ruby
require "async"
require "async/limiter"

# Default - no timing constraints
limiter = Async::Limiter::Limited.new(5)  # Only concurrency limit applies

# Explicit None strategy
timing = Async::Limiter::Timing::None.new
limiter = Async::Limiter::Limited.new(5, timing: timing)

# All 5 tasks start immediately (limited by concurrency only)
10.times do |i|
	limiter.async do |task|
		puts "Task #{i} started at #{Time.now}"
		task.sleep 1
	end
end
```

## Sliding Window Strategy

Provides smooth rate limiting with continuous rolling time windows:

### Basic Usage

```ruby
# Allow 3 operations within any 1-second sliding window
timing = Async::Limiter::Timing::SlidingWindow.new(
	1.0,                                             # 1-second window
	Async::Limiter::Timing::BurstStrategy::Greedy,   # Burst behavior
	3                                                # 3 operations per window
)

limiter = Async::Limiter::Limited.new(10, timing: timing)

# First 3 operations execute immediately
# Subsequent operations are rate limited to maintain 3/second
10.times do |i|
	limiter.async do |task|
		puts "Operation #{i} at #{Time.now}"
		task.sleep 0.1
	end
end
```

### Burst Strategies

Different burst behaviors affect how operations are scheduled:

```ruby
# Greedy: Allow immediate bursts up to the limit
greedy_timing = Async::Limiter::Timing::SlidingWindow.new(
	2.0,                                           # 2-second window
	Async::Limiter::Timing::BurstStrategy::Greedy, # Allow bursts
	6                                              # 6 operations per 2 seconds
)

# Conservative: Spread operations evenly over time
conservative_timing = Async::Limiter::Timing::SlidingWindow.new(
	2.0,                                               # 2-second window
	Async::Limiter::Timing::BurstStrategy::Conservative, # Even distribution
	6                                                  # 6 operations per 2 seconds
)

# Compare behaviors
puts "=== Greedy Strategy ==="
greedy_limiter = Async::Limiter::Limited.new(10, timing: greedy_timing)

10.times do |i|
	greedy_limiter.async do |task|
		puts "Greedy #{i} at #{Time.now}"
	end
end

sleep(3)  # Wait for completion

puts "=== Conservative Strategy ==="
conservative_limiter = Async::Limiter::Limited.new(10, timing: conservative_timing)

10.times do |i|
	conservative_limiter.async do |task|
		puts "Conservative #{i} at #{Time.now}"
	end
end
```

### Cost-Based Rate Limiting

Operations can consume different amounts of the rate limit:

```ruby
timing = Async::Limiter::Timing::SlidingWindow.new(
	1.0,                                             # 1-second window
	Async::Limiter::Timing::BurstStrategy::Greedy,
	10.0                                             # 10 units per second
)

limiter = Async::Limiter::Limited.new(20, timing: timing)

Async do
	# Light operations (0.5 units each)
	5.times do |i|
		limiter.acquire(cost: 0.5) do
			puts "Light operation #{i} at #{Time.now}"
		end
	end
	
	# Heavy operations (3.0 units each)
	3.times do |i|
		limiter.acquire(cost: 3.0) do
			puts "Heavy operation #{i} at #{Time.now}"
		end
	end
	
	# Total: 5 * 0.5 + 3 * 3.0 = 11.5 units.
	# Will be rate limited to 10 units/second.
end
```

## Fixed Window Strategy

Provides rate limiting with discrete time boundaries:

### Basic Usage

```ruby
# Allow 5 operations per 2-second window with fixed boundaries
timing = Async::Limiter::Timing::FixedWindow.new(
	2.0,                                             # 2-second windows
	Async::Limiter::Timing::BurstStrategy::Greedy,   # Allow bursting within window
	5                                                # 5 operations per window
)

limiter = Async::Limiter::Limited.new(10, timing: timing)

# Operations are grouped into discrete 2-second windows
15.times do |i|
	limiter.async do |task|
		puts "Operation #{i} at #{Time.now}"
		task.sleep 0.1
	end
end

# Output shows operations grouped in batches of 5, every 2 seconds
```

### Window Boundary Behavior

```ruby
# Demonstrate window boundaries
timing = Async::Limiter::Timing::FixedWindow.new(
	1.0,                                             # 1-second windows
	Async::Limiter::Timing::BurstStrategy::Greedy,
	3                                                # 3 operations per window
)

limiter = Async::Limiter::Limited.new(10, timing: timing)

start_time = Time.now

10.times do |i|
	limiter.async do |task|
		elapsed = Time.now - start_time
		puts "Operation #{i} at #{elapsed.round(2)}s (window #{elapsed.to_i})"
	end
end

# Operations are clearly grouped by 1-second boundaries:
# Window 0: operations 0, 1, 2 (0.00s - 0.99s)
# Window 1: operations 3, 4, 5 (1.00s - 1.99s)
# Window 2: operations 6, 7, 8 (2.00s - 2.99s)
# etc.
```

### Burst vs Conservative in Fixed Windows

```ruby
# Greedy allows all operations immediately within each window
greedy_timing = Async::Limiter::Timing::FixedWindow.new(
	2.0, Async::Limiter::Timing::BurstStrategy::Greedy, 4
)

# Conservative spreads operations evenly within each window
conservative_timing = Async::Limiter::Timing::FixedWindow.new(
	2.0, Async::Limiter::Timing::BurstStrategy::Conservative, 4
)

puts "=== Greedy Fixed Window ==="
greedy_limiter = Async::Limiter::Limited.new(10, timing: greedy_timing)

8.times do |i|
	greedy_limiter.async do |task|
		puts "Greedy #{i} at #{Time.now}"
	end
end

sleep(5)  # Wait for completion

puts "=== Conservative Fixed Window ==="
conservative_limiter = Async::Limiter::Limited.new(10, timing: conservative_timing)

8.times do |i|
	conservative_limiter.async do |task|
		puts "Conservative #{i} at #{Time.now}"
	end
end

# Greedy: 4 operations immediately, then wait 2s, then 4 more immediately
# Conservative: Operations spread evenly within each 2-second window
```

## Leaky Bucket Strategy

Provides smooth token-based rate limiting with automatic token replenishment:

### Basic Usage

```ruby
# 5 tokens per second leak rate, 20 token capacity
timing = Async::Limiter::Timing::LeakyBucket.new(
	5.0,   # 5 tokens/second leak rate
	20.0   # 20 token capacity
)

limiter = Async::Limiter::Limited.new(30, timing: timing)

# Bucket starts empty and fills as operations are attempted
30.times do |i|
	limiter.async do |task|
		puts "Operation #{i} at #{Time.now}"
		task.sleep 0.1
	end
end

# First ~20 operations may execute quickly (burst capacity)
# Then operations are limited to 5/second (leak rate)
```

### Initial Token Level

```ruby
# Start with bucket partially filled
timing = Async::Limiter::Timing::LeakyBucket.new(
	2.0,    # 2 tokens/second leak rate
	10.0,   # 10 token capacity
	initial_level: 8.0  # Start with 8 tokens available
)

limiter = Async::Limiter::Limited.new(20, timing: timing)

# First 8 operations execute immediately (using initial tokens)
# Then rate limited to 2/second
15.times do |i|
	limiter.async do |task|
		puts "Operation #{i} at #{Time.now}"
	end
end
```

### Cost-Based Token Consumption

```ruby
timing = Async::Limiter::Timing::LeakyBucket.new(
	10.0,  # 10 tokens/second leak rate
	50.0   # 50 token capacity
)

limiter = Async::Limiter::Limited.new(100, timing: timing)

Async do
	# Cheap operations (0.5 tokens each)
	10.times do |i|
		limiter.acquire(cost: 0.5) do
			puts "Cheap operation #{i} at #{Time.now}"
		end
	end
	
	# Expensive operations (5.0 tokens each)
	5.times do |i|
		limiter.acquire(cost: 5.0) do
			puts "Expensive operation #{i} at #{Time.now}"
		end
	end
	
	# Mixed costs will be rate limited based on total token consumption.
end
```

### Token Bucket Dynamics

```ruby
# Demonstrate token accumulation and depletion
timing = Async::Limiter::Timing::LeakyBucket.new(
	3.0,   # 3 tokens/second
	15.0   # 15 token capacity
)

limiter = Async::Limiter::Limited.new(50, timing: timing)

# Phase 1: Burst consumption (depletes bucket)
puts "=== Phase 1: Burst consumption ==="
20.times do |i|
	limiter.async do |task|
		puts "Burst #{i} at #{Time.now}"
	end
end

# Wait for burst to complete and tokens to accumulate
sleep(10)

# Phase 2: Another burst (uses accumulated tokens)
puts "=== Phase 2: After token accumulation ==="
10.times do |i|
	limiter.async do |task|
		puts "Second burst #{i} at #{Time.now}"
	end
end
```

## Combining Strategies with Different Limiters

### Generic Limiter + Timing

Pure rate limiting without concurrency constraints:

```ruby
# Unlimited concurrency, but rate limited
timing = Async::Limiter::Timing::SlidingWindow.new(1.0, 
	Async::Limiter::Timing::BurstStrategy::Greedy, 5)

limiter = Async::Limiter::Generic.new(timing: timing)

# All 20 tasks start immediately, but timing strategy controls execution rate
20.times do |i|
	limiter.async do |task|
		puts "Task #{i} at #{Time.now}"
		task.sleep 0.1
	end
end
```

### Limited Limiter + Timing

Both concurrency and rate limiting:

```ruby
# Max 3 concurrent, and max 2 per second
timing = Async::Limiter::Timing::LeakyBucket.new(2.0, 10.0)
limiter = Async::Limiter::Limited.new(3, timing: timing)

# Operations are constrained by both limits
10.times do |i|
	limiter.async do |task|
		puts "Task #{i} started at #{Time.now} (concurrent: #{i % 3})"
		task.sleep 2  # Longer task to show concurrency limit
		puts "Task #{i} finished at #{Time.now}"
	end
end

# Shows interplay between concurrency (3 max) and rate (2/second) limits
```

### Queued Limiter + Timing

Priority-based resource allocation with rate limiting:

```ruby
require "async/queue"

# Create resource queue
queue = Async::Queue.new
3.times { |i| queue.push("worker_#{i}") }

# Add timing constraint
timing = Async::Limiter::Timing::FixedWindow.new(2.0,
	Async::Limiter::Timing::BurstStrategy::Greedy, 4)

limiter = Async::Limiter::Queued.new(queue, timing: timing)

# High and low priority tasks with timing constraints
tasks = []

# Low priority background tasks
5.times do |i|
	tasks << limiter.async do |task|
		limiter.acquire(priority: 1) do |worker|
			puts "Background task #{i} using #{worker} at #{Time.now}"
			task.sleep 1
		end
	end
end

# High priority user tasks
3.times do |i|
	tasks << limiter.async do |task|
		limiter.acquire(priority: 10) do |worker|
			puts "User task #{i} using #{worker} at #{Time.now}"
			task.sleep 1
		end
	end
end

tasks.each(&:wait)
```

## Real-World Examples

### API Rate Limiting

```ruby
class RateLimitedAPIClient
	def initialize(requests_per_second: 10, burst_capacity: 50)
		# Leaky bucket allows bursts up to capacity, then steady rate:
		timing = Async::Limiter::Timing::LeakyBucket.new(
			requests_per_second.to_f,
			burst_capacity.to_f
		)
		
		@limiter = Async::Limiter::Generic.new(timing: timing)
	end
	
	def make_request(endpoint, cost: 1.0)
		@limiter.acquire(cost: cost) do
		# Make actual HTTP request:
		puts "Making request to #{endpoint} at #{Time.now}"
			simulate_http_request(endpoint)
		end
	end
	
	def make_expensive_request(endpoint)
		# Heavy requests consume more rate limit:
		make_request(endpoint, cost: 5.0)
	end
	
	private
	
	def simulate_http_request(endpoint)
		sleep(0.1)  # Simulate network delay
		"Response from #{endpoint}"
	end
end

# Usage
client = RateLimitedAPIClient.new(requests_per_second: 5, burst_capacity: 20)

Async do
	# Burst of requests (uses burst capacity):
	10.times do |i|
		client.make_request("/api/data/#{i}")
	end
	
	# Mix of normal and expensive requests:
	5.times do |i|
		if i.even?
			client.make_request("/api/normal/#{i}")
		else
			client.make_expensive_request("/api/heavy/#{i}")
		end
	end
end
```

### Background Job Processing

```ruby
class JobProcessor
	def initialize
		# Process jobs in batches every 30 seconds, up to 50 jobs per batch
		timing = Async::Limiter::Timing::FixedWindow.new(
			30.0,  # 30-second windows
			Async::Limiter::Timing::BurstStrategy::Greedy,
			50     # 50 jobs per window
		)
		
		@limiter = Async::Limiter::Limited.new(10, timing: timing)  # Max 10 concurrent
	end
	
	def process_job(job)
		cost = calculate_job_cost(job)
		
		@limiter.acquire(cost: cost) do
			puts "Processing #{job.type} job #{job.id} (cost: #{cost}) at #{Time.now}"
			
			case job.type
			when :quick
				sleep(0.5)
			when :normal
				sleep(2.0)
			when :heavy
				sleep(5.0)
			end
			
			puts "Completed job #{job.id}"
		end
	end
	
	private
	
	def calculate_job_cost(job)
		case job.type
		when :quick then 0.5
		when :normal then 1.0
		when :heavy then 3.0
		end
	end
end

# Mock job structure
Job = Struct.new(:id, :type)

# Usage
processor = JobProcessor.new

jobs = [
	Job.new(1, :quick), Job.new(2, :normal), Job.new(3, :heavy),
	Job.new(4, :quick), Job.new(5, :normal), Job.new(6, :heavy),
	Job.new(7, :quick), Job.new(8, :normal), Job.new(9, :heavy),
]

Async do
	jobs.each do |job|
		processor.process_job(job)
	end
end

# Jobs are processed in batches based on the 30-second fixed window
# Heavy jobs consume more of the batch quota due to higher cost
```

### Adaptive Rate Limiting

```ruby
class AdaptiveRateLimiter
	def initialize
		@current_rate = 10.0
		@current_capacity = 50.0
		@timing = create_timing
		@limiter = Async::Limiter::Generic.new(timing: @timing)
		@success_count = 0
		@error_count = 0
	end
	
	def make_request(endpoint)
		@limiter.acquire do
			begin
				result = simulate_request(endpoint)
				@success_count += 1
				adjust_rate_on_success
				result
			rescue => error
				@error_count += 1
				adjust_rate_on_error
				raise
			end
		end
	end
	
	private
	
	def create_timing
		Async::Limiter::Timing::LeakyBucket.new(@current_rate, @current_capacity)
	end
	
	def adjust_rate_on_success
		# Increase rate gradually on success
		if @success_count % 10 == 0 && @error_count == 0
			@current_rate = [@current_rate * 1.1, 50.0].min
			@current_capacity = [@current_capacity * 1.1, 200.0].min
			update_timing
			puts "Rate increased to #{@current_rate}/sec (capacity: #{@current_capacity})"
		end
	end
	
	def adjust_rate_on_error
		# Decrease rate on errors
		@current_rate = [@current_rate * 0.8, 1.0].max
		@current_capacity = [@current_capacity * 0.8, 10.0].max
		update_timing
		puts "Rate decreased to #{@current_rate}/sec (capacity: #{@current_capacity})"
		
		# Reset counters
		@success_count = 0
		@error_count = 0
	end
	
	def update_timing
		new_timing = create_timing
		@limiter.instance_variable_set(:@timing, new_timing)
	end
	
	def simulate_request(endpoint)
		sleep(0.1)
		
		# Simulate occasional errors to trigger rate adjustment
		if rand < 0.1  # 10% error rate
			raise "API Error: Rate limit exceeded"
		end
		
		"Success: #{endpoint}"
	end
end

# Usage
limiter = AdaptiveRateLimiter.new

Async do
	100.times do |i|
		begin
			result = limiter.make_request("/api/endpoint/#{i}")
			puts "Request #{i}: #{result}"
		rescue => error
			puts "Request #{i} failed: #{error.message}"
		end
		
		sleep(0.05)  # Small delay between requests
	end
end

# Shows adaptive behavior: rate increases on success, decreases on errors
```

## Best Practices

### Choosing the Right Strategy

- **None**: Use when you only need concurrency control without rate limiting
- **SlidingWindow**: Best for smooth, continuous rate limiting
- **FixedWindow**: Good for batch processing or when you want discrete time periods
- **LeakyBucket**: Ideal for APIs with burst tolerance and smooth long-term rates

### Configuration Guidelines

- **Window size**: Smaller windows provide more responsive rate limiting but may be less efficient
- **Burst strategy**: Use Greedy for better user experience, Conservative for more predictable load
- **Capacity**: Set burst capacity based on your system's ability to handle temporary load spikes
- **Leak rate**: Should match your sustainable processing rate

### Performance Considerations

- **Memory usage**: Timing strategies maintain internal state; size depends on configuration
- **CPU overhead**: More complex strategies (SlidingWindow) have higher computational cost
- **Accuracy**: Shorter time windows provide more accurate rate limiting but use more resources

### Error Handling

- **Cost validation**: Always handle ArgumentError when costs exceed capacity
- **Timeout handling**: Set appropriate timeouts based on your timing strategy's behavior
- **Graceful degradation**: Have fallback strategies when rate limits are exceeded

Timing strategies provide powerful tools for controlling the rate and timing of operations in your async applications. Choose the strategy that best matches your specific rate limiting requirements and system constraints.
