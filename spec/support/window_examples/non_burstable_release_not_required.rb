RSpec.shared_examples :non_burstable_release_not_required do
  describe "non burstable, release not required" do
    include_examples :window_limiter

    let(:burstable) { false }
    let(:release_required) { false }

    include_examples :set_decimal_limit_non_burstable

    describe "#async" do
      include_context :async_processing

      context "when limit is 1" do
        let(:limit) { 1 }
        let(:repeats) { 3 }

        context "when task duration is shorter than window" do
          let(:task_duration) { 0.1 }

          it "executes the tasks sequentially" do
            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", be_within(50).of(1000)],
              ["task 1 end", be_within(50).of(1100)],
              ["task 2 start", be_within(50).of(2000)],
              ["task 2 end", be_within(50).of(2100)]
            )
          end

          it "ensures max number of concurrent tasks equals limit" do
            expect(maximum).to eq limit
          end

          it "ensures the results are in the correct order" do
            expect(result).to eq (0...repeats).to_a
          end

          it "ensures max number of started tasks in a window == limit" do
            expect(max_per_second).to eq limit
          end

          it "ensures max number of started tasks in a window frame equals 1" do
            expect(max_per_frame).to eq 1
          end
        end

        context "when task duration is longer than window" do
          let(:task_duration) { 1.5 }

          it "executes the tasks sequentially" do
            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 1 start", be_within(50).of(1000)], # task 0 and 1 run
              ["task 0 end", be_within(50).of(1500)],
              ["task 2 start", be_within(50).of(2000)], # task 1 and 2 run
              ["task 1 end", be_within(50).of(2500)],
              ["task 2 end", be_within(50).of(3500)]
            )
          end

          it "ensures max number of concurrent tasks is greater than limit" do
            expect(maximum).to eq 2
          end

          it "ensures the results are in the correct order" do
            expect(result).to eq (0...repeats).to_a
          end

          it "ensures max number of started tasks in a window == limit" do
            expect(max_per_second).to eq limit
          end

          it "ensures max number of started tasks in a window frame equals 1" do
            expect(max_per_frame).to eq 1
          end
        end
      end

      context "when limit is 3" do
        let(:limit) { 3 } # window_frame is 1.0 / 3 = 0.33
        let(:repeats) { 6 }

        context "when task duration is shorter than window frame" do
          let(:task_duration) { 0.1 }

          it "executes the tasks sequentially" do
            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", be_within(50).of(333)],
              ["task 1 end", be_within(50).of(433)],
              ["task 2 start", be_within(50).of(666)],
              ["task 2 end", be_within(50).of(766)],
              ["task 3 start", be_within(50).of(1000)],
              ["task 3 end", be_within(50).of(1100)],
              ["task 4 start", be_within(75).of(1333)],
              ["task 4 end", be_within(75).of(1433)],
              ["task 5 start", be_within(75).of(1666)],
              ["task 5 end", be_within(75).of(1766)]
            )
          end

          it "ensures max number of concurrent tasks is 1" do
            expect(maximum).to eq 1
          end

          it "ensures the results are in the correct order" do
            expect(result).to eq (0...repeats).to_a
          end

          it "ensures max number of started tasks in a window == limit" do
            expect(max_per_second).to eq limit
          end

          it "ensures max number of started tasks in a window frame equals 1" do
            expect(max_per_frame).to eq 1
          end
        end

        context "when task duration is longer than window frame" do
          let(:task_duration) { 1.5 }

          it "intermingles task execution" do
            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 1 start", be_within(50).of(333)],
              ["task 2 start", be_within(50).of(666)],
              ["task 3 start", be_within(50).of(1000)],
              ["task 4 start", be_within(50).of(1333)], # 5 concurrent tasks
              ["task 0 end", be_within(50).of(1500)],
              ["task 5 start", be_within(50).of(1666)],
              ["task 1 end", be_within(50).of(1833)],
              ["task 2 end", be_within(50).of(2166)],
              ["task 3 end", be_within(75).of(2500)],
              ["task 4 end", be_within(75).of(2833)],
              ["task 5 end", be_within(75).of(3166)]
            )
          end

          it "ensures max number of concurrent tasks is greater than limit" do
            expect(maximum).to eq 5
          end

          it "ensures the results are in the correct order" do
            expect(result).to eq (0...repeats).to_a
          end

          # Sliding window sometimes does not start 'limit' tasks in the same
          # second.
          it "ensures max number of started tasks in a window <= limit" do
            expect(max_per_second).to be <= limit
          end

          it "ensures max number of started tasks in a window frame equals 1" do
            expect(max_per_frame).to eq 1
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
        let(:window_frame) { window.to_f / limit }

        context "when no locks are acquired" do
          include_examples :limiter_is_not_blocking
        end

        context "when a single lock is acquired" do
          include_context :single_lock_is_acquired
          include_examples :limiter_is_blocking

          context "after window frame passes" do
            before { wait_until_next_window_frame }
            include_examples :limiter_is_not_blocking
          end
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
