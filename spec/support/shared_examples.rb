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
