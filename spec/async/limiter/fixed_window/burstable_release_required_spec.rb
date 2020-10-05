require "async/barrier"
require "async/limiter/fixed_window"

require_relative "../chainable_async_examples"

RSpec.describe Async::Limiter::FixedWindow do
  describe "burstable, release required" do
    let(:burstable) { true }
    let(:release_required) { true }
    it_behaves_like :chainable_async

    subject(:limiter) do
      described_class.new(
        burstable: burstable,
        release_required: release_required
      )
    end

    describe "#async" do
      subject(:limiter) do
        described_class.new(
          limit,
          burstable: burstable,
          release_required: release_required
        )
      end

      context "when processing work in batches" do
        let(:repeats) { 20 }
        let(:limit) { 4 }
        let(:acquired_times) { [] }
        let(:max_per_second) { acquired_times.map(&:to_i).tally.values.max }

        before do
          current, @maximum = 0, 0

          @result = repeats.times.map { |i|
            limiter.async do |task|
              current += 1
              acquired_times << Async::Clock.now
              @maximum = [current, @maximum].max
              task.sleep(rand * 0.1)
              current -= 1

              i
            end
          }.map(&:wait)
        end

        it "checks max number of concurrent task equals the limit" do
          expect(@maximum).to eq limit
        end

        it "checks the results are in the correct order" do
          expect(@result).to eq (0...repeats).to_a
        end

        it "checks max number of tasks in a time window equals the limit" do
          expect(max_per_second).to eq limit
        end
      end

      context "when tasks run one at a time" do
        let(:limit) { 1 }
        let(:order) { [] }
        let(:acquired_times) { [] }
        let(:max_per_second) { acquired_times.map(&:to_i).tally.values.max }

        before do
          3.times.map { |i|
            limiter.async do |task|
              acquired_times << Async::Clock.now
              order << i
              task.sleep(0.1)
              order << i
            end
          }.map(&:wait)
        end

        it "the tasks are executed sequentially" do
          expect(order).to eq [0, 0, 1, 1, 2, 2]
        end

        it "ensures max number of tasks in a time window equals the limit" do
          expect(max_per_second).to eq limit
        end
      end

      context "when tasks are executed concurrently" do
        let(:limit) { 3 }
        let(:order) { [] }

        before do
          3.times.map { |i|
            limiter.async do |task|
              order << i
              task.sleep(0.1)
              order << i
            end
          }.map(&:wait)
        end

        it "the order of tasks is intermingled" do
          expect(order).to eq [0, 1, 2, 0, 1, 2]
        end
      end
    end

    describe "invalid inputs" do
      context "when limit is invalid" do
        it "raises an error" do
          expect {
            described_class.new(0)
          }.to raise_error(Async::Limiter::ArgumentError)

          expect {
            described_class.new(-1)
          }.to raise_error(Async::Limiter::ArgumentError)
        end
      end

      context "when min_limit is invalid" do
        it "raises an error" do
          expect {
            described_class.new(min_limit: -1)
          }.to raise_error(Async::Limiter::ArgumentError)
        end
      end

      context "when max_limit is invalid" do
        it "raises an error" do
          expect {
            described_class.new(max_limit: -1)
          }.to raise_error(Async::Limiter::ArgumentError)
        end
      end

      context "when max_limit is lower than min_limit" do
        it "raises an error" do
          expect {
            described_class.new(max_limit: 5, min_limit: 10)
          }.to raise_error(Async::Limiter::ArgumentError)
        end
      end

      context "when limit is lower than min_limit" do
        it "raises an error" do
          expect {
            described_class.new(1, min_limit: 10)
          }.to raise_error(Async::Limiter::ArgumentError)
        end
      end
    end

    describe "#count" do
      it "counts the number of acquired locks" do
        expect(limiter.count).to eq 0

        limiter.acquire
        expect(limiter.count).to eq 1
      end
    end

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

    describe "#limit=" do
      subject(:limiter) do
        described_class.new(
          3,
          burstable: burstable,
          release_required: release_required,
          max_limit: 10,
          min_limit: 2
        )
      end

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

    describe "#blocking?" do
      context "with a default limiter" do
        it "is blocking when a single lock is acquired" do
          expect(limiter).not_to be_blocking

          limiter.acquire
          expect(limiter).to be_blocking
        end

        it "is blocking when a lock is released in the same window" do
          start_window = Async::Clock.now.to_i
          limiter.acquire
          expect(limiter).to be_blocking

          limiter.release
          current_window = Async::Clock.now.to_i
          raise "time window changed" unless current_window == start_window
          # We're still in the same time window
          expect(limiter).to be_blocking
        rescue RuntimeError
          # This prevents intermittent spec failures.
          retry
        end

        it "is blocking when a lock is not released in the next window" do
          limiter.acquire
          expect(limiter).to be_blocking

          Async::Task.current.sleep(limiter.window + 0.01)
          expect(limiter).to be_blocking
          limiter.release
          expect(limiter).not_to be_blocking
        end
      end

      context "when limit is 2" do
        subject(:limiter) do
          described_class.new(
            2,
            burstable: burstable,
            release_required: release_required
          )
        end

        it "is blocking when 2 locks are acquired" do
          expect(limiter).not_to be_blocking

          limiter.acquire
          expect(limiter).not_to be_blocking

          limiter.acquire
          expect(limiter).to be_blocking
        end
      end
    end

    describe "#acquire/#release" do
      it "increments count" do
        limiter.acquire
        expect(limiter.count).to eq 1

        limiter.release
        expect(limiter.count).to eq 0
      end
    end

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
end
