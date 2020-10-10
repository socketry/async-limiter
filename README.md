# Async Limiter

Gem `async-limiter`.

These limiters are available:

- [Async::Limiter::Concurrent](#asynclimiterconcurrent)
- [Async::Limiter::Window::Fixed](#asynclimiterwindowfixed)
- [Async::Limiter::Window::Sliding](#asynclimiterwindowsliding)
- [Async::Limiter::Window::Continuous](#asynclimiterwindowcontinuous)
- [Async::Limiter::Unlimited](#asynclimiterunlimited)

### `Async::Limiter::Concurrent`

Limits running tasks to "x number of tasks at the same time".

Note: this class has the same logic as
[Async::Semaphore](https://github.com/socketry/async).

**Example**

```ruby
require "async"
require "async/limiter/concurrent"

Async do
  limiter = Async::Limiter::Concurrent.new(2)

  4.times do
    limiter.async do |task|
      task.sleep 1
    end
  end
end
```

The above limiter runs two tasks concurrently. After first two tasks are done,
it runs the next two tasks.

The total duration of the above example is 2s.

**Notes**

- Question: how many tasks per second does concurrent limiter run?<br/>
  Answer: That depends on the task duration, but the "per second count" is not
  limited. A concurrent limiter with a limit of 1 can run ~1000 tasks per
  second if each task takes only 1ms to execute.<br/>
  The only guarantee is: it will run a maximum of 1 task at any point in time.
  See window limiters if you want "maximum of x tasks per second" limiter.

### `Async::Limiter::Window::Fixed`

- Limits running tasks to "x number of tasks at the same time".
- Guarantees "only x new tasks will start in this time window".

**Example**

```ruby
require "async"
require "async/limiter/window/fixed"

Async do
  limiter = Async::Limiter::Window::Fixed.new(2, window: 2)

  4.times do
    limiter.async do |task|
      task.sleep 1
    end
  end
end
```

The above limiter runs two tasks concurrently at any point in time. After first
two tasks are done it waits for the 2-second window to finish before running
the next two tasks.

The total duration of the above example is a minimum 2s and maximum 3s.
This variation exists because the example can start near the end of the first
2-second window.

**Notes**

- By default, this limiter waits until a task is done before freeing an
  internal lock for the next task. Example: if limit is 1, window is 1s and
  tasks take 10s to finish, the limiter will start one task every 10s because
  only 1 task can run at the same time.<br/>
  In order to always run tasks on schedule pass `lock: false` on
  initialization. Limiter with limit 1, window 1s where tasks run 10s will
  start a new task every second.
- Say you have a fixed window limiter with a limit 10 and window of 1s.
  You run 10 short tasks at 10:10:10.999 (hour, minute, second, ms) and they
  all complete in 1ms. The next 10 tasks will run at 10:10:11.000 (1ms
  later)!
  So a limiter with a limit 10 and window 1 can run 20 tasks within ~1ms, how
  come? Reason why the above scenario is ok is because each 10 tasks run in
  their own 1-second window. First 10 tasks run at 10:10:10, and second 10
  tasks run at 10:10:11.
  See sliding or continuous window limiter if this is a problem.
- Fixed window limiter runs tasks in "bursts" at the start of the interval.
  See continuous window limiter if this is a problem.

### `Async::Limiter::Window::Sliding`

- Limits running tasks to "x number of tasks at the same time".
- Guarantees "only x new tasks will start in this time window".

**Example**

```ruby
require "async"
require "async/limiter/window/sliding"

Async do
  limiter = Async::Limiter::Window::Sliding.new(2, window: 2)

  4.times do
    limiter.async do |task|
      task.sleep 1
    end
  end
end
```

The above limiter runs two tasks concurrently at any point in time. After first
two tasks are done it waits for the 2-second window to finish before running
the next two tasks.

The total duration of the above example is 3s.

**Differences between fixed and sliding window limiter**

- A **fixed** window limiter with a limit 1 and window of 1s will
  run 1 task at 10:10:10.999. If that task finishes in 1ms it will run next
  task at 10:10:11.000 (because that's the start of the next fixed 1-second
  window).
- A **sliding** window limiter with a limit 1 and window of 1s will
  run 1 task at 10:10:10.999. If that task finishes in 1ms it will wait until
  the start of the next sliding window at 10:10:11.999 before starting the next
  task.

**Notes**

- By default, this limiter waits until a task is done before freeing an
  internal lock for the next task. Example: if limit is 1, window is 1s and
  tasks take 10s to finish, the limiter will start one task every 10s because
  only 1 task can run at the same time.<br/>
  In order to always run tasks on schedule pass `lock: false` on
  initialization. Limiter with limit 1, window 1s where tasks run 10s will
  start a new task every second.
- Sliding window limiter runs tasks in "bursts" at the start of the interval.
  See continuous window limiter if this is a problem.

### `Async::Limiter::Window::Continuous`

- Limits running tasks to "x number of tasks at the same time".
- Guarantees "only x new tasks will start this window".
- It prevents "task bursts" by evenly spacing out new task creation within a
  window.

*Example*

```ruby
require "async"
require "async/limiter/window/continuous"

Async do
  limiter = Async::Limiter::Window::Continuous.new(2, window: 1)

  4.times do
    limiter.async do |task|
      task.sleep 0.1
    end
  end
end
```

The above limiter runs one task when it starts. It then waits 500ms (half the
window duration) before running the second task in the first window.
500ms later (1s after start) new window begins and it runs the third task,
waits another 500ms and runs the last task.

The total duration of the above example is 1.6s.

**Notes**

- By default, this limiter waits until a task is done before freeing an
  internal lock for the next task. Example: if limit is 1, window is 1s and
  tasks take 10s to finish, the limiter will start one task every 10s because
  only 1 task can run at the same time.<br/>
  In order to always run tasks on schedule pass `lock: false` on
  initialization. Limiter with limit 1, window 1s where tasks run 10s will
  start a new task every second.
- Tasks are always evenly spaced out within a window. New task starts after
  `window.to_f / limit` time after the previous task started.

### `Async::Limiter::Unlimited`

Always runs tasks immediately, without limits.
This limiter is not intended for production use.

*Example*

```ruby
require "async"
require "async/limiter/unlimited"

Async do
  limiter = Async::Limiter::Unlimited.new

  100.times do
    limiter.async do |task|
      task.sleep 1
    end
  end
end
```

All 100 tasks in the example above start immediately and run at the same time.

The total duration of the above example is 1s.

### Updating `limit`

All limiters except `Async::Limiter::Unlimited` have `#limit=`. It allows
live updating of the `limit`. Just set a new value and limiter will do the
right thing while it actively runs existing tasks.

**Decimal values**

Setting `limit` to decimal values is allowed. Examples:

- Set limit to 0.5 and window to 1.
- Set limit to 1.5 and window to 2.5.

Since decimal value for a limit  doesn't make sense (how do you run half a task
per second?), decimal limit is internally always converted to a whole number
and window is adjusted appriately. So half a task per second actually runs as
one task in two seconds.

### Updating `window`

All window limiters have `#window=`. It allows live updating of the `window`.
Just set a new value and limiter will do the right thing while it actively runs
existing tasks.

### Maintenance

This project is maintained actively, but on a slow schedule. Due to author's
current life obligations it is likely:

- No support questions will be answered.
- No issues or new features will be worked on.

If you want to help you can submit a small (e.g. 5 lines of code) and focused
PR. PRs containing big changes or new, unasked for features require a lot
of time to review and I often don't get to those.

### Credits

Inspiration and parts of the code taken from
[Async::Semaphore](https://github.com/socketry/async).

### License

[MIT](LICENSE)

You have full permission to fork, copy, and do whatever you want with this code.
