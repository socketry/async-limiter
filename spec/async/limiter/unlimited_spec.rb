require "async/limiter/unlimited"

RSpec.describe Async::Limiter::Unlimited do
  subject(:limiter) { described_class.new }

  include_examples :chainable_async
  include_examples :barrier
  include_examples :count

  describe "#async" do
    include_context :async_processing

    let(:repeats) { 50 }
    let(:task_duration) { 0.1 }

    it "always executes tasks concurrently" do
      expect(task_stats).to contain_exactly(
        *repeats.times.flat_map do |index|
          [
            ["task #{index} start", be_within(10).of(0)],
            ["task #{index} end", be_within(50).of(100)]
          ]
        end
      )
    end

    it "ensures max number of concurrent tasks equals number of tasks" do
      expect(maximum).to eq repeats
    end

    it "ensures the results are in the correct order" do
      expect(result).to eq (0...repeats).to_a
    end
  end

  describe "#blocking?" do
    context "when 10M locks are acquired" do
      before do
        10_000_000.times { limiter.acquire }
      end

      it "is never blocking" do
        expect(limiter).not_to be_blocking
      end
    end
  end
end
