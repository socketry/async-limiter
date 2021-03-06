require "async/barrier"

RSpec.shared_examples :chainable_async do
  let(:parent) { double }

  # This example was taken from https://github.com/socketry/async
  context "when parent is passed via #new" do
    subject { described_class.new(parent: parent) }

    it "chains async to parent" do
      expect(parent).to receive(:async)

      subject.async do
      end
    end
  end

  context "when parent is passed via #async" do
    subject { described_class.new }

    it "chains async to parent" do
      expect(parent).to receive(:async)

      subject.async(parent: parent) do
      end
    end
  end
end

RSpec.shared_examples :invalid_inputs do
  describe "invalid inputs" do
    shared_examples :raises_argument_error do
      it "raises an error" do
        expect {
          limiter
        }.to raise_error(Async::Limiter::ArgumentError)
      end
    end

    context "when limit is invalid" do
      context "when limit is 0" do
        let(:limit) { 0 }

        include_examples :raises_argument_error
      end

      context "when limit is -1" do
        let(:limit) { -1 }

        include_examples :raises_argument_error
      end
    end
  end
end

RSpec.shared_examples :limit= do
  describe "#limit=" do
    let(:limit) { 3 }

    before do
      expect(limiter.limit).to eq 3
    end

    context "when new limit is zero" do
      it "raises argument error" do
        expect {
          limiter.limit = 0
        }.to raise_error Async::Limiter::ArgumentError
      end
    end

    context "when new limit is a negative number" do
      let(:new_limit) { - rand(1000) }

      it "raises argument error" do
        expect {
          limiter.limit = new_limit
        }.to raise_error Async::Limiter::ArgumentError
      end
    end

    context "when new limit is a positive number" do
      let(:new_limit) { limit + 1 + rand(1000) }

      it "updates limit" do
        expect {
          limiter.limit = new_limit
        }.to change { limiter.limit }.from(limit).to(new_limit)
      end
    end
  end
end

RSpec.shared_examples :barrier do
  context "with barrier" do
    let(:capacity) { 2 }
    let(:barrier) { Async::Barrier.new }
    let(:repeats) { capacity * 2 }

    it "executes several tasks and waits using a barrier" do
      repeats.times do
        subject.async(parent: barrier) do |task|
          task.sleep 0.1
        end
      end

      expect(barrier.size).to eq repeats
      barrier.wait
    end
  end
end

RSpec.shared_examples :count do
  describe "#count" do
    context "default" do
      it "is zero" do
        expect(limiter.count).to eq 0
      end
    end

    context "when a lock is acquired" do
      it "increments count" do
        limiter.acquire
        expect(limiter.count).to eq 1
      end
    end

    context "when a lock is acquired and then released" do
      it "resets count" do
        limiter.acquire
        limiter.release
        expect(limiter.count).to eq 0
      end
    end
  end
end

RSpec.shared_examples :window_limiter do
  def next_fixed_window_start_time
    limit = limiter.limit
    window = limiter.window

    # Logic from #update_concurrency
    real_window =
      if defined?(new_window)
        # Prevent intermittent failures in specs that change window.
        new_window
      else
        case limit
        when 0...1
          window / limit
        when (1..)
          if window >= 2
            window * limit.floor / limit
          else
            window * limit.ceil / limit
          end
        end
      end

    window_index = (Async::Clock.now / real_window).floor
    window_index.next * real_window
  end

  def wait_until_next_fixed_window_start
    delay = next_fixed_window_start_time - Async::Clock.now

    Async::Task.current.sleep(delay)
  end

  def wait_until_next_window
    Async::Task.current.sleep(window)
  end

  def wait_until_next_window_frame
    window_frame = window.to_f / limit

    Async::Task.current.sleep(window_frame)
  end

  let(:limit) { 1 }
  let(:window) { 1 }

  subject(:limiter) do
    described_class.new(
      limit,
      window: window,
      lock: lock
    )
  end

  include_examples :chainable_async
  include_examples :invalid_inputs
  include_examples :limit=
  include_examples :window=
  include_examples :barrier
  include_examples :count
  include_examples :sync
  include_examples :acquire_with_block
  include_examples :custom_queue
end

RSpec.shared_context :async_processing do
  require "async/limiter/window/fixed"

  let(:acquired_times) { [] }
  let(:max_per_second) do
    acquired_times.map(&:to_i).tally.values.max
  end
  let(:max_per_window) do
    acquired_times.map { |time|
      time.truncate(1)
    }.tally.values.max
  end
  let(:window_frame) { window.to_f / limit }
  let(:window_frame_indexes) do
    acquired_times.map { |time|
      ((time - start_time.to_i) / window_frame).floor
    }
  end
  let(:max_per_frame) { window_frame_indexes.tally.values.max }
  let(:task_stats) { [] }

  attr_accessor :maximum
  attr_accessor :start_time

  let(:result) do
    current = 0
    self.maximum = 0

    if described_class == Async::Limiter::Window::Fixed
      wait_until_next_fixed_window_start
    end

    self.start_time = Async::Clock.now

    repeats.times.map { |i|
      limiter.async do |task|
        current += 1
        acquired_times << Async::Clock.now
        task_stats << [
          "task #{i} start",
          ((Async::Clock.now - start_time) * 1000).to_i # ms
        ]
        self.maximum = [current, maximum].max

        task.sleep(task_duration)

        current -= 1
        task_stats << [
          "task #{i} end",
          ((Async::Clock.now - start_time) * 1000).to_i # ms
        ]
        i
      end
    }.map(&:wait)
  end

  before do
    result
  end
end

RSpec.shared_context :blocking_contexts do
  shared_examples :limiter_is_not_blocking do
    it "is not blocking" do
      expect(limiter).not_to be_blocking
    end
  end

  shared_examples :limiter_is_blocking do
    it "is blocking" do
      expect(limiter).to be_blocking
    end
  end

  shared_context :single_lock_is_acquired do
    before do
      limiter.acquire
    end
  end

  shared_context :all_locks_are_acquired do
    before do
      limit.times { limiter.acquire }
    end
  end

  shared_context :all_locks_are_released_immediately do
    before do
      limit.times { limiter.acquire }
      limit.times { limiter.release }
    end
  end

  shared_context :no_locks_are_released_until_next_window do
    before do
      limit.times { limiter.acquire }
      wait_until_next_window
    end
  end
end

RSpec.shared_examples :sync do
  describe "#sync" do
    context "without a block" do
      it "raises an error" do
        expect {
          limiter.sync
        }.to raise_error(LocalJumpError)
      end
    end

    context "with a block" do
      attr_accessor :value

      before do
        self.value = nil

        limiter.sync do
          Async::Task.current.sleep(0.01)
          self.value = "value"
        end
      end

      it "performs the work synchronously" do
        expect(value).to eq "value"
      end
    end
  end
end

RSpec.shared_examples :acquire_with_block do
  describe "#acquire with a block" do
    attr_accessor :value

    before do
      self.value = nil

      limiter.acquire do
        Async::Task.current.sleep(0.01)
        self.value = "value"
      end
    end

    it "performs the work synchronously" do
      expect(value).to eq "value"
    end
  end
end

RSpec.shared_examples :custom_queue do
  context "with a custom queue" do
    let(:repeats) { 4 }
    let(:task_duration) { 0.1 }
    let(:result) { [] }

    subject(:limiter) do
      described_class.new(limit, queue: NaivePriorityQueue.new)
    end

    shared_examples :runs_tasks_based_on_priority do
      it "runs tasks based on the priority" do
        expect(result).to eq [0, 3, 2, 1]
      end
    end

    describe "#async" do
      before do
        repeats.times.map { |i|
          Async::Task.current.async do
            limiter.async(i) { |task|
              task.sleep(task_duration)
              result << i
            }.wait
          end
        }.map(&:wait)
      end

      include_examples :runs_tasks_based_on_priority
    end

    describe "#sync" do
      before do
        repeats.times.map { |i|
          Async::Task.current.async do
            limiter.sync(i) do |task|
              task.sleep(task_duration)
              result << i
            end
          end
        }.map(&:wait)
      end

      include_examples :runs_tasks_based_on_priority
    end

    describe "#acquire" do
      before do
        repeats.times.map { |i|
          Async::Task.current.async do |task|
            limiter.acquire(i)
            task.sleep(task_duration)
            result << i
            limiter.release
          end
        }.map(&:wait)
      end

      include_examples :runs_tasks_based_on_priority
    end
  end
end
