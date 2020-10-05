require "async/barrier"
require "async/rspec"
require "async/limiter/concurrent"

require_relative "chainable_async_examples"

# These specs were taken from https://github.com/socketry/async and appropriated

RSpec.describe Async::Limiter::Concurrent do
  include_context Async::RSpec::Reactor

  it_behaves_like :chainable_async

  subject(:limiter) { described_class.new }

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
