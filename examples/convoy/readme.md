# Convoy Effect Example

This example demonstrates the "convoy effect" problem in rate limiting and how the `Ordered` timing wrapper solves it.

## The Problem: Starvation

When using rate limiting with variable costs, high-cost operations can be **starved** by continuous streams of low-cost operations:

1. **High-cost task** (cost: 8.0) starts waiting for capacity
2. **Small-cost tasks** (cost: 0.5) arrive continuously  
3. As capacity becomes available, **small tasks consume it faster** than the high-cost task can accumulate what it needs
4. **High-cost task never executes** - it's starved indefinitely

## The Solution: Ordered Timing

The `Ordered` timing wrapper preserves **FIFO (First-In-First-Out) ordering**:

```ruby
# Without ordering - starvation can occur
timing = LeakyBucket.new(2.0, 10.0)

# With ordering - FIFO prevents starvation  
timing = Ordered.new(LeakyBucket.new(2.0, 10.0))
```

## Running the Example

```bash
$ ruby examples/convoy/convoy.rb
```

### With Ordering (default):
- High-cost task completes first (FIFO preserved)
- Small tasks wait their turn
- **No starvation**

### Without Ordering:
Comment out line 13 to see starvation:
```ruby
# timing = Async::Limiter::Timing::Ordered.new(timing)
```

- High-cost task may never complete
- Small tasks consume capacity as it becomes available
- **Starvation occurs**

## Key Insights

### Trade-offs:

**Ordered (FIFO):**
- ✅ **Fairness**: No starvation, predictable completion order
- ❌ **Efficiency**: Lower overall throughput, head-of-line blocking

**Unordered (Efficiency-first):**  
- ✅ **Efficiency**: Higher throughput, better resource utilization
- ❌ **Fairness**: High-cost operations can be starved

### When to Use Each:

**Use Ordered when:**
- Fairness is critical (e.g., user-facing operations)
- Starvation would be unacceptable (e.g., critical system tasks)
- Predictable completion order is required

**Use Unordered when:**
- Maximum throughput is the priority
- All operations have similar costs
- Occasional starvation is acceptable

## Technical Details

The Ordered wrapper works by **serializing access** to the underlying timing strategy:
- Only one task can interact with the timing strategy at a time
- Tasks are processed in strict arrival order
- Prevents race conditions that allow smaller tasks to "jump ahead"

This elegant solution adds FIFO ordering to any timing strategy without changing its core rate limiting logic.
