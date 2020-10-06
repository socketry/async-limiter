require "async/limiter/concurrent"

# These specs were taken from https://github.com/socketry/async and appropriated

RSpec.describe Async::Limiter::Concurrent do
  let(:limit) { 1 }
  let(:min_limit) { 1 }
  let(:max_limit) { Async::Limiter::MAX_LIMIT }

  subject(:limiter) do
    described_class.new(
      limit,
      min_limit: min_limit,
      max_limit: max_limit
    )
  end

  include_examples :chainable_async
  include_examples :invalid_inputs
  include_examples :limit
  include_examples :limit=
  include_examples :barrier
  include_examples :count

  describe "#async" do
    subject(:limiter) { described_class.new(limit) }

    context "when processing work in batches" do
      let(:repeats) { 40 }
      let(:limit) { 4 }

      before do
        current, @maximum = 0, 0

        @result = repeats.times.map { |i|
          limiter.async do |task|
            current += 1
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
    end

    context "when tasks run one at a time" do
      let(:limit) { 1 }
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

      it "the tasks are executed sequentially" do
        expect(order).to eq [0, 0, 1, 1, 2, 2]
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

  describe "#blocking?" do
    context "with a default limiter" do
      it "is blocking when a single lock is acquired" do
        expect(limiter).not_to be_blocking

        limiter.acquire
        expect(limiter).to be_blocking
      end
    end

    context "when limit is 2" do
      subject(:limiter) { described_class.new(2) }

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
