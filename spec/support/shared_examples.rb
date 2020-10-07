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

    context "when min_limit is invalid" do
      let(:min_limit) { -1 }

      include_examples :raises_argument_error
    end

    context "when max_limit is invalid" do
      let(:max_limit) { -1 }

      include_examples :raises_argument_error
    end

    context "when max_limit is lower than min_limit" do
      let(:max_limit) { 5 }
      let(:min_limit) { 10 }

      include_examples :raises_argument_error
    end

    context "when limit is lower than min_limit" do
      let(:limit) { 1 }
      let(:min_limit) { 10 }

      include_examples :raises_argument_error
    end
  end
end

RSpec.shared_examples :limit do
  describe "#limit" do
    context "with a default value" do
      specify do
        expect(limiter.limit).to eq 1
      end
    end

    context "when limit is incremented" do
      specify do
        limiter.limit += 1
        expect(limiter.limit).to eq 2
      end
    end
  end
end

RSpec.shared_examples :limit= do
  describe "#limit=" do
    let(:limit) { 3 }
    let(:max_limit) { 10 }
    let(:min_limit) { 2 }

    before do
      expect(limiter.limit).to eq 3
    end

    context "when new limit is within max and min limits" do
      it "updates limit" do
        limiter.limit = 5
        expect(limiter.limit).to eq 5
      end
    end

    context "when new limit is greater than max_limit" do
      it "updates limit to max_limit" do
        limiter.limit = 50
        expect(limiter.limit).to eq 10
      end
    end

    context "when new limit is lower than min_limit" do
      it "updates limit to min_limit" do
        limiter.limit = 1
        expect(limiter.limit).to eq 2
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

RSpec.shared_examples :fixed_window_limiter do
  def wait_until_next_fixed_window_start
    window_index = (Async::Clock.now / limiter.window).floor
    next_window_start_time = window_index.next * limiter.window
    delay = next_window_start_time - Async::Clock.now

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
  let(:min_limit) { Async::Limiter::MIN_WINDOW_LIMIT }
  let(:max_limit) { Async::Limiter::MAX_LIMIT }

  subject(:limiter) do
    described_class.new(
      limit,
      window: window,
      min_limit: min_limit,
      max_limit: max_limit,
      burstable: burstable,
      release_required: release_required
    )
  end

  include_examples :chainable_async
  include_examples :invalid_inputs
  include_examples :limit
  include_examples :limit=
  include_examples :barrier
  include_examples :count
end

RSpec.shared_context :async_processing do
  require "async/limiter/fixed_window"

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

    if described_class == Async::Limiter::FixedWindow
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
