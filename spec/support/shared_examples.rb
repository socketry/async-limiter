RSpec.shared_examples :chainable_async do
  let(:parent) { double }

  # This example was taken from https://github.com/socketry/async
  context "when parent is passed via #new" do
    subject { described_class.new(parent: parent) }

    it "chains async to parent" do
      expect(parent).to receive(:async)

      subject.async do
      end
    end
  end

  context "when parent is passed via #async" do
    subject { described_class.new }

    it "chains async to parent" do
      expect(parent).to receive(:async)

      subject.async(parent: parent) do
      end
    end
  end
end

RSpec.shared_examples :invalid_inputs do
  describe "invalid inputs" do
    context "when limit is invalid" do
      it "raises an error" do
        expect {
          described_class.new(
            0,
            burstable: burstable,
            release_required: release_required
          )
        }.to raise_error(Async::Limiter::ArgumentError)

        expect {
          described_class.new(
            -1,
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
          described_class.new(
            1,
            min_limit: 10,
            burstable: burstable,
            release_required: release_required
          )
        }.to raise_error(Async::Limiter::ArgumentError)
      end
    end
  end
end

RSpec.shared_examples :limit do
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
end

RSpec.shared_examples :limit= do
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
end

RSpec.shared_examples :barrier do
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

RSpec.shared_examples :count do
  describe "#count" do
    context "default" do
      it "is zero" do
        expect(limiter.count).to eq 0
      end
    end

    context "when a lock is acquired" do
      it "increments count" do
        limiter.acquire
        expect(limiter.count).to eq 1
      end
    end

    context "when a lock is acquired and then released" do
      it "resets count" do
        limiter.acquire
        limiter.release
        expect(limiter.count).to eq 0
      end
    end
  end
end
