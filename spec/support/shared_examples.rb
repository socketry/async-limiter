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
