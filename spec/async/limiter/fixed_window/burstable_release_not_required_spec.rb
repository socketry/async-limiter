require "async/barrier"
require "async/limiter/fixed_window"

RSpec.describe Async::Limiter::FixedWindow do
  describe "burstable, release not required" do
    it_behaves_like :chainable_async
    include_context :fixed_window_limiter_helpers

    let(:burstable) { true }
    let(:release_required) { false }

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
          window: window,
          burstable: burstable,
          release_required: release_required
        )
      end

      context "when processing work in batches" do
        let(:window) { 0.1 } # shorter window to speed the specs
        let(:repeats) { 20 }
        let(:limit) { 4 }
        let(:acquired_times) { [] }
        let(:max_per_window) do
          acquired_times.map { |time|
            time.truncate(1)
          }.tally.values.max
        end

        before do
          current, @maximum = 0, 0

          @result = repeats.times.map { |i|
            limiter.async do |task|
              current += 1
              acquired_times << Async::Clock.now
              @maximum = [current, @maximum].max
              task.sleep(0.2) # task lasts longer than a window
              current -= 1

              i
            end
          }.map(&:wait)
        end

        it "checks max number of concurrent task exceeds the limit" do
          expect(@maximum).to eq 3 * limit
        end

        it "checks the results are in the correct order" do
          expect(@result).to eq (0...repeats).to_a
        end

        it "checks max number of tasks in a time window equals the limit" do
          expect(max_per_window).to eq limit
        end
      end

      context "when tasks run one at a time" do
        let(:window) { 1 }
        let(:limit) { 1 }
        let(:order) { [] }
        let(:task_stats) { [] }

        before do
          wait_until_next_fixed_window_start
          start_time = Async::Clock.now

          6.times.map { |i|
            limiter.async do |task|
              task_stats << [
                "task #{i} start",
                ((Async::Clock.now - start_time) * 1000).to_i # ms
              ]

              order << i
              task.sleep(task_duration)
              order << i

              task_stats << [
                "task #{i} end",
                ((Async::Clock.now - start_time) * 1000).to_i # ms
              ]
            end
          }.map(&:wait)
        end

        context "when task duration is shorter than window" do
          let(:task_duration) { 0.1 }

          it "runs the tasks sequentially" do
            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", be_within(50).of(1000)],
              ["task 1 end", be_within(50).of(1100)],
              ["task 2 start", be_within(50).of(2000)],
              ["task 2 end", be_within(50).of(2100)],
              ["task 3 start", be_within(50).of(3000)],
              ["task 3 end", be_within(50).of(3100)],
              ["task 4 start", be_within(50).of(4000)],
              ["task 4 end", be_within(50).of(4100)],
              ["task 5 start", be_within(50).of(5000)],
              ["task 5 end", be_within(50).of(5100)]
            )
          end
        end

        context "when task duration is longer than window" do
          let(:task_duration) { 1.5 }

          it "intermingles task execution" do
            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 1 start", be_within(50).of(1000)],
              ["task 0 end", be_within(50).of(1500)],
              ["task 2 start", be_within(50).of(2000)],
              ["task 1 end", be_within(50).of(2500)],
              ["task 3 start", be_within(50).of(3000)],
              ["task 2 end", be_within(50).of(3500)],
              ["task 4 start", be_within(50).of(4000)],
              ["task 3 end", be_within(50).of(4500)],
              ["task 5 start", be_within(50).of(5000)],
              ["task 4 end", be_within(50).of(5500)],
              ["task 5 end", be_within(50).of(6500)]
            )
          end
        end
      end

      context "when tasks are executed concurrently" do
        let(:window) { 1 }
        let(:limit) { 3 }
        let(:order) { [] }
        let(:task_stats) { [] }

        before do
          wait_until_next_fixed_window_start
          start_time = Async::Clock.now

          6.times.map { |i|
            limiter.async do |task|
              task_stats << [
                "task #{i} start",
                ((Async::Clock.now - start_time) * 1000).to_i # ms
              ]

              order << i
              task.sleep(task_duration)
              order << i

              task_stats << [
                "task #{i} end",
                ((Async::Clock.now - start_time) * 1000).to_i # ms
              ]
            end
          }.map(&:wait)
        end

        context "when task duration is shorter than window" do
          let(:task_duration) { 0.1 }

          it "runs the tasks concurrently" do
            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", 0],
              ["task 1 end", be_within(50).of(100)],
              ["task 2 start", 0],
              ["task 2 end", be_within(50).of(100)],
              ["task 3 start", be_within(50).of(1000)],
              ["task 3 end", be_within(50).of(1100)],
              ["task 4 start", be_within(50).of(1000)],
              ["task 4 end", be_within(50).of(1100)],
              ["task 5 start", be_within(50).of(1000)],
              ["task 5 end", be_within(50).of(1100)]
            )
          end
        end

        context "when task duration is longer than window" do
          let(:task_duration) { 1.5 }

          it "intermingles task execution" do
            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(1500)],
              ["task 1 start", 0],
              ["task 1 end", be_within(50).of(1500)],
              ["task 2 start", 0],
              ["task 2 end", be_within(50).of(1500)],
              ["task 3 start", be_within(50).of(1000)],
              ["task 3 end", be_within(50).of(2500)],
              ["task 4 start", be_within(50).of(1000)],
              ["task 4 end", be_within(50).of(2500)],
              ["task 5 start", be_within(50).of(1000)],
              ["task 5 end", be_within(50).of(2500)]
            )
          end
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

        it "is not blocking when a lock is not released in the next window" do
          limiter.acquire
          expect(limiter).to be_blocking

          Async::Task.current.sleep(limiter.window + 0.01)
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
