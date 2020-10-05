require "async/barrier"
require "async/limiter/fixed_window"

require_relative "../chainable_async_examples"

RSpec.describe Async::Limiter::FixedWindow do
  describe "non burstable, release required" do
    let(:burstable) { false }
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
        described_class.new(limit,
          burstable: burstable,
          release_required: release_required
        )
      end

      context "when processing work in batches" do
        let(:repeats) { 20 }
        let(:limit) { 4 } # window frame is 1.0 / 4 = 0.25 seconds
        let(:acquired_times) { [] }
        let(:max_per_second) { acquired_times.map(&:to_i).tally.values.max }

        before do
          current, @maximum = 0, 0

          @result = repeats.times.map { |i|
            limiter.async do |task|
              current += 1
              acquired_times << Async::Clock.now
              @maximum = [current, @maximum].max
              task.sleep(rand * 0.01)
              current -= 1

              i
            end
          }.map(&:wait)
        end

        it "checks max number of concurrent task equals 1" do
          expect(@maximum).to eq 1
        end

        it "checks the results are in the correct order" do
          expect(@result).to eq (0...repeats).to_a
        end

        it "checks max number of tasks in a time window equals the limit" do
          expect(max_per_second).to eq limit
        end
      end

      context "when limit is 1" do
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

        it "executes the tasks sequentially" do
          expect(order).to eq [0, 0, 1, 1, 2, 2]
        end

        it "ensures max number of tasks in a time window equals the limit" do
          expect(max_per_second).to eq limit
        end
      end

      context "when limit is 3" do
        let(:limit) { 3 } # window_frame is 1.0 / 3 = 0.33
        let(:order) { [] }
        let(:task_stats) { [] }

        before do
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

        context "when task duration is shorter than window frame" do
          let(:task_duration) { 0.1 }

          it "executes the tasks sequentially" do
            expect(order).to eq [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
          end
        end

        context "when task duration is longer than window frame" do
          let(:task_duration) { 1.5 }

          it "intermingles task execution" do
            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 1 start", be_within(50).of(333)],
              ["task 2 start", be_within(50).of(666)],

              ["task 0 end",   be_within(50).of(1500)], # resumes task 3
              ["task 3 start", be_within(50).of(1500)],

              ["task 1 end",   be_within(50).of(1833)], # resumes task 4
              ["task 4 start", be_within(50).of(1833)],

              ["task 2 end",   be_within(50).of(2166)], # resumes task 5
              ["task 5 start", be_within(50).of(2166)],

              ["task 3 end",   be_within(50).of(3000)],
              ["task 4 end",   be_within(50).of(3333)],
              ["task 5 end",   be_within(50).of(3666)]
            )
          end
        end
      end
    end

    describe "invalid inputs" do
      context "when limit is invalid" do
        it "raises an error" do
          expect {
            described_class.new(0,
              burstable: burstable,
              release_required: release_required
            )
          }.to raise_error(Async::Limiter::ArgumentError)

          expect {
            described_class.new(-1,
              burstable: burstable,
              release_required: release_required
            )
          }.to raise_error(Async::Limiter::ArgumentError)
        end
      end

      context "when min_limit is invalid" do
        it "raises an error" do
          expect {
            described_class.new(
              min_limit: -1,
              burstable: burstable,
              release_required: release_required
            )
          }.to raise_error(Async::Limiter::ArgumentError)
        end
      end

      context "when max_limit is invalid" do
        it "raises an error" do
          expect {
            described_class.new(
              max_limit: -1,
              burstable: burstable,
              release_required: release_required
            )
          }.to raise_error(Async::Limiter::ArgumentError)
        end
      end

      context "when max_limit is lower than min_limit" do
        it "raises an error" do
          expect {
            described_class.new(
              max_limit: 5,
              min_limit: 10,
              burstable: burstable,
              release_required: release_required
            )
          }.to raise_error(Async::Limiter::ArgumentError)
        end
      end

      context "when limit is lower than min_limit" do
        it "raises an error" do
          expect {
            described_class.new(1,
              min_limit: 10,
              burstable: burstable,
              release_required: release_required
            )
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
        described_class.new(3,
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
          begin
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
          described_class.new(2,
            burstable: burstable,
            release_required: release_required
          )
        end

        it "is blocking for the window_frame duration after #acquire" do
          expect(limiter).not_to be_blocking

          limiter.acquire
          expect(limiter).to be_blocking

          Async::Task.current.sleep(0.5) # window frame duration
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
