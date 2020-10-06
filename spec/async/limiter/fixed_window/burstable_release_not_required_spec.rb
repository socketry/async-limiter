require "async/limiter/fixed_window"

RSpec.describe Async::Limiter::FixedWindow do
  describe "burstable, release not required" do
    let(:burstable) { true }
    let(:release_required) { false }

    include_examples :fixed_window_limiter

    describe "#async" do
      include_context :async_processing

      context "when processing work in batches" do
        let(:limit) { 4 }
        let(:window) { 0.1 } # shorter window to speed the specs
        let(:repeats) { 20 }
        let(:task_duration) { 0.2 } # task lasts longer than a window

        it "checks max number of concurrent task exceeds the limit" do
          expect(maximum).to eq 3 * limit
        end

        it "checks the results are in the correct order" do
          expect(result).to eq (0...repeats).to_a
        end

        it "checks max number of tasks in a time window equals the limit" do
          expect(max_per_window).to eq limit
        end
      end

      context "when tasks run one at a time" do
        let(:limit) { 1 }
        let(:window) { 1 }
        let(:repeats) { 6 }

        context "when task duration is shorter than window" do
          let(:task_duration) { 0.1 }

          # intermittent failures
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
        let(:limit) { 3 }
        let(:window) { 1 }
        let(:repeats) { 6 }

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

    describe "#blocking?" do
      include_context :blocking_contexts

      before do
        wait_until_next_fixed_window_start
      end

      context "with a default limit" do
        context "when no locks are acquired" do
          include_examples :limiter_is_not_blocking
        end

        context "when a single lock is acquired" do
          include_context :single_lock_is_acquired
          include_examples :limiter_is_blocking

          context "after window passes" do
            before { wait_until_next_window }
            include_examples :limiter_is_not_blocking
          end
        end

        context "when all the locks are released immediately" do
          include_context :all_locks_are_released_immediately
          include_examples :limiter_is_blocking

          context "after window passes" do
            before { wait_until_next_window }
            include_examples :limiter_is_not_blocking
          end
        end

        context "when no locks are released until the next window" do
          include_context :no_locks_are_released_until_next_window
          include_examples :limiter_is_not_blocking
        end
      end

      context "when limit is 2" do
        let(:limit) { 2 }

        context "when no locks are acquired" do
          include_examples :limiter_is_not_blocking
        end

        context "when a single lock is acquired" do
          include_context :single_lock_is_acquired
          include_examples :limiter_is_not_blocking
        end

        context "when all the locks are acquired" do
          include_context :all_locks_are_acquired
          include_examples :limiter_is_blocking

          context "after window passes" do
            before { wait_until_next_window }
            include_examples :limiter_is_not_blocking
          end
        end

        context "when all the locks are released immediately" do
          include_context :all_locks_are_released_immediately
          include_examples :limiter_is_blocking

          context "after window passes" do
            before { wait_until_next_window }
            include_examples :limiter_is_not_blocking
          end
        end

        context "when no locks are released until the next window" do
          include_context :no_locks_are_released_until_next_window
          include_examples :limiter_is_not_blocking
        end
      end
    end
  end
end
