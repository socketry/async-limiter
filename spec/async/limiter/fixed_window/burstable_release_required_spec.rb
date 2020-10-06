require "async/limiter/fixed_window"

RSpec.describe Async::Limiter::FixedWindow do
  describe "burstable, release required" do
    let(:burstable) { true }
    let(:release_required) { true }

    include_examples :fixed_window_limiter

    describe "#async" do
      include_context :async_processing

      context "when processing work in batches" do
        let(:limit) { 4 }
        let(:repeats) { 20 }

        def task_duration
          rand * 0.1
        end

        it "checks max number of concurrent tasks equals the limit" do
          expect(maximum).to eq limit
        end

        it "checks the results are in the correct order" do
          expect(result).to eq (0...repeats).to_a
        end

        it "checks max number of tasks in a time window equals the limit" do
          expect(max_per_second).to eq limit
        end
      end

      context "when tasks run one at a time" do
        let(:limit) { 1 }
        let(:repeats) { 3 }
        let(:task_duration) { 0.1 }

        it "the tasks are executed sequentially" do
          expect(task_stats).to contain_exactly(
            ["task 0 start", 0],
            ["task 0 end", be_within(50).of(100)],
            ["task 1 start", be_within(50).of(1000)],
            ["task 1 end", be_within(50).of(1100)],
            ["task 2 start", be_within(50).of(2000)],
            ["task 2 end", be_within(50).of(2100)]
          )
        end

        it "ensures max number of tasks in a time window equals the limit" do
          expect(max_per_second).to eq limit
        end
      end

      context "when tasks are executed concurrently" do
        let(:limit) { 3 }
        let(:repeats) { 3 }
        let(:task_duration) { 0.1 }

        it "the order of tasks is intermingled" do
          expect(task_stats).to contain_exactly(
            ["task 0 start", 0],
            ["task 0 end", be_within(50).of(100)],
            ["task 1 start", 0],
            ["task 1 end", be_within(50).of(100)],
            ["task 2 start", 0],
            ["task 2 end", be_within(50).of(100)]
          )
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
  end
end
