# Token Usage

This guide explains how to use tokens for advanced resource management with `async-limiter`. Tokens provide sophisticated resource handling with support for re-acquisition and automatic cleanup.

## What Are Tokens?

Tokens encapsulate acquired resources and provide advanced resource management capabilities:

- **Re-acquisition**: Re-acquire resources after release with new options.
- **Resource tracking**: Know whether a token is active or released.
- **Automatic cleanup**: Guaranteed resource release with block usage

## Usage

Use `Token.acquire` instead of limiter-specific methods:

```ruby
require "async"
require "async/limiter"

limiter = Async::Limiter::Limited.new(5)

# Acquire a token:
token = Async::Limiter::Token.acquire(limiter)
puts "Acquired: #{token.resource}"

# Use the resource
perform_operation(token.resource)

# Release when done:
token.release
```

For most limiters, `token.resource` will simply be the value `true`.

### Block-Based Token Usage

For automatic cleanup, use blocks:

```ruby
# Automatic release with blocks:
Async::Limiter::Token.acquire(limiter) do |token|
	puts "Using: #{token.resource}"
	perform_operation(token.resource)
	# Automatically released when block exits.
end
```

## Re-Acquisition

Tokens can be released and re-acquired:

```ruby
# Initial acquisition:
token = Async::Limiter::Token.acquire(limiter)

# Use and release:
perform_operation(token.resource)
token.release

# Re-acquire later with new options:
token.acquire(priority: 5, cost: 2.0)
puts "Re-acquired: #{token.resource}"

token.release
```

If you specify a timeout, and the limiter cannot be acquired, `nil` will be returned.

### Re-Acquisition with Blocks

```ruby
token = Async::Limiter::Token.acquire(limiter)

# Use the resource:
perform_operation(token.resource)
token.release

# Re-acquire and execute with automatic cleanup:
result = token.acquire(cost: 2.0) do |resource|
	perform_expensive_operation(resource)
end

puts "Operation result: #{result}"
```
