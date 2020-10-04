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

