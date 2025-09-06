# Releases

## Unreleased

The 2.0.x release should be considered somewhat unstable.

- **Breaking**: Complete API redesign. The v1.x classes (`Async::Limiter::Concurrent`, `Async::Limiter::Unlimited`, etc.) have been replaced with a new inheritance-based architecture.
- **Breaking**: Removed `blocking?` method due to inherent race conditions. Use `acquire(timeout: 0)` for non-blocking checks.
- **Breaking**: Timing strategies now use consumption-only model (no explicit `release` methods).
- **Breaking**: Window classes moved from `limiter/window/` to `limiter/timing/` with renamed classes.

### New Architecture (replaces v1.x classes)

- **New**: `Async::Limiter::Generic` - Unlimited concurrency with timing coordination (replaces `Async::Limiter::Unlimited`).
- **New**: `Async::Limiter::Limited` - Counting semaphore with configurable limits (replaces `Async::Limiter::Concurrent`).  
- **New**: `Async::Limiter::Queued` - Queue-based resource distribution with priority/timeout support (completely new functionality).

### Advanced Timeout Features

- **New**: Unified timeout API - `acquire(timeout: 0/nil/seconds)` provides non-blocking and timed acquisition.
- **New**: Precise deadline tracking using `Async::Deadline` (requires async v2.31.0+).
- **New**: Convoy effect prevention - quick timeout operations not blocked by slow operations.
- **New**: Accurate timeout propagation - remaining time correctly passed through timing and concurrency layers.

### Cost-Based Acquisition

- **New**: Cost-based acquisition - `acquire(cost: 1.5)` for proportional resource consumption.
- **New**: Starvation prevention - validates cost against timing strategy `maximum_cost` capacity.
- **New**: Flexible operation weighting - light operations consume fewer resources than heavy ones.

### Enhanced Timing Strategies

- Add `Async::Limiter::Timing::LeakyBucket` for token bucket rate limiting with automatic leaking.
- Add `Async::Limiter::Timing::FixedWindow` for discrete time boundary enforcement.
- Rename `Async::Limiter::Timing::Window` to `Async::Limiter::Timing::SlidingWindow` for clarity.
- **Breaking**: Remove `release` methods from timing strategies (consumption-only model).
- **Breaking**: Remove `try_acquire` methods from timing strategies (unified timeout API).

### Token-Based Resource Management

- **New**: `acquire_token` method returns `Token` objects for advanced resource management.
- **New**: Token re-acquisition with different options - `token.acquire(priority: 5)`.
- **New**: Automatic token cleanup with block usage.

### Thread Safety and Performance

- **New**: Race condition elimination by moving timing coordination inside mutex.
- **New**: Fast path optimizations using `deadline.expired?` checks.
- **New**: Atomic timing coordination prevents race conditions in concurrent access.
- **Improved**: Test performance using time simulation instead of actual sleep calls.
