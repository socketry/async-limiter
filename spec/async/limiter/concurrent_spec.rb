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

    context "when limit is 1" do
      let(:limit) { 1 }

      it "allows only one task at a time" do
        order = []

        3.times.map { |i|
          limiter.async do |task|
            order << i
            task.sleep(0.1)
            order << i
          end
        }.map(&:wait)

        expect(order).to be == [0, 0, 1, 1, 2, 2]
      end
    end

    context "when limit is 3" do
      let(:limit) { 3 }

      it "allows tasks to execute concurrently" do
        order = []

        3.times.map { |i|
          limiter.async do |task|
            order << i
            task.sleep(0.1)
            order << i
          end
        }.map(&:wait)

        expect(order).to be == [0, 1, 2, 0, 1, 2]
      end
    end
  end

  # TODO: remove
  xdescribe "#waiting" do
    subject { described_class.new(0) }

    it "handles exceptions thrown while waiting" do
      expect do
        reactor.with_timeout(0.1) do
          subject.acquire do
          end
        end
      end.to raise_error(Async::TimeoutError)

      expect(subject.waiting).to be_empty
    end
  end

  describe "#count" do
    it "counts the number of current locks" do
      expect(limiter.count).to eq 0

      limiter.acquire
      expect(limiter.count).to eq 1
    end
  end

  describe "#limit" do
    it "has a default limit" do
      expect(limiter.limit).to eq 1
    end
  end

  describe "#blocking?" do
    it "will be blocking when acquired" do
      expect(limiter).not_to be_blocking

      limiter.acquire
      expect(limiter).to be_blocking
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
