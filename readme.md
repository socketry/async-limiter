# Async Limiter

A Ruby gem providing flexible concurrency and rate limiting for async applications.

[![Development Status](https://github.com/socketry/async-limiter/workflows/Test/badge.svg)](https://github.com/socketry/async-limiter/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/async-limiter/) for more details.

  - [Getting Started](https://socketry.github.io/async-limiter/guides/getting-started/index) - This guide explains how to get started the `async-limiter` gem for controlling concurrency and rate limiting in Ruby applications.

  - [Generic Limiter](https://socketry.github.io/async-limiter/guides/generic-limiter/index) - This guide explains the <code class="language-ruby">Async::Limiter::Generic</code> class, which provides unlimited concurrency by default and serves as the base implementation for all other limiters. It's ideal when you need timing constraints without concurrency limits, or when building custom limiter implementations.

  - [Limited Limiter](https://socketry.github.io/async-limiter/guides/limited-limiter/index) - This guide explains the <code class="language-ruby">Async::Limiter::Limited</code> class, which provides semaphore-style concurrency control, enforcing a maximum number of concurrent operations. It's perfect for controlling concurrency when you have limited capacity or want to prevent system overload.

  - [Queued Limiter](https://socketry.github.io/async-limiter/guides/queued-limiter/index) - This guide explains the <code class="language-ruby">Async::Limiter::Queued</code> class, which provides priority-based task scheduling with optional resource management. Its key feature is priority-based acquisition where higher priority tasks get access first, with optional support for distributing specific resources from a pre-populated queue.

  - [Timing Strategies](https://socketry.github.io/async-limiter/guides/timing-strategies/index) - This guide explains how to use timing strategies to provide rate limiting and timing constraints that can be combined with any limiter. They control *when* operations can execute, while limiters control *how many* can execute concurrently.

## See Also

  - [falcon](https://github.com/socketry/falcon) - A high-performance web server
  - [async-http](https://github.com/socketry/async-http) - Asynchronous HTTP client and server
  - [async](https://github.com/socketry/async) - The core async framework

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
