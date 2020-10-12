require "async/limiter/concurrent"

# These specs were taken from https://github.com/socketry/async and appropriated

RSpec.describe Async::Limiter::Concurrent do
  let(:limit) { 1 }

  subject(:limiter) { described_class.new(limit) }

  include_examples :chainable_async
  include_examples :invalid_inputs
  include_examples :limit=
  include_examples :barrier
  include_examples :count
  include_examples :sync
  include_examples :acquire_with_block
  include_examples :custom_queue

  describe "#async" do
    include_context :async_processing

    context "when limit is 1" do
      let(:limit) { 1 }
      let(:repeats) { 3 }
      let(:task_duration) { 0.1 }

      it "the tasks are executed sequentially" do
        expect(task_stats).to contain_exactly(
          ["task 0 start", 0],
          ["task 0 end", be_within(50).of(100)],
          ["task 1 start", be_within(50).of(100)],
          ["task 1 end", be_within(50).of(200)],
          ["task 2 start", be_within(50).of(200)],
          ["task 2 end", be_within(50).of(300)]
        )
      end

      it "ensures max number of concurrent tasks equals 1" do
        expect(maximum).to eq 1
      end

      it "ensures the results are in the correct order" do
        expect(result).to eq (0...repeats).to_a
      end
    end

    context "when limit is 3" do
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

      it "ensures max number of concurrent tasks equals limit" do
        expect(maximum).to eq limit
      end

      it "ensures the results are in the correct order" do
        expect(result).to eq (0...repeats).to_a
      end
    end
  end

  describe "#blocking?" do
    include_context :blocking_contexts

    context "with a default limit" do
      context "when no locks are acquired" do
        include_examples :limiter_is_not_blocking
      end

      context "when a single lock is acquired" do
        include_context :single_lock_is_acquired
        include_examples :limiter_is_blocking

        context "after release" do
          before { limiter.release }
          include_examples :limiter_is_not_blocking
        end
      end

      context "when all the locks are released immediately" do
        include_context :all_locks_are_released_immediately
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

        context "after release" do
          before { limiter.release }
          include_examples :limiter_is_not_blocking
        end
      end

      context "when all the locks are released immediately" do
        include_context :all_locks_are_released_immediately
        include_examples :limiter_is_not_blocking
      end
    end
  end
end
