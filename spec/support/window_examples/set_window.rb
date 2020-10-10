RSpec.shared_examples :window= do
  describe "#window=" do
    let(:window) { 2 }

    before do
      expect(limiter.window).to eq 2
    end

    context "when new window is zero" do
      it "raises argument error" do
        expect {
          limiter.window = 0
        }.to raise_error Async::Limiter::ArgumentError
      end
    end

    context "when new window is a negative number" do
      let(:new_window) { - rand(10) }

      it "raises argument error" do
        expect {
          limiter.window = new_window
        }.to raise_error Async::Limiter::ArgumentError
      end
    end

    context "when new window is a positive number" do
      let(:new_window) { window + 1 + rand(10) }

      it "updates window" do
        expect {
          limiter.window = new_window
        }.to change { limiter.window }.from(window).to(new_window)
      end
    end

    shared_examples :changes_task_execution_to_window_1 do
      it "changes task execution to new window" do
        expect(task_stats).to contain_exactly(
          ["task 0 start", 0],
          ["task 0 end", be_within(50).of(100)],
          # Limiter window changed
          ["task 1 start", be_within(50).of(1000)],
          ["task 1 end", be_within(50).of(1100)],
          ["task 2 start", be_within(50).of(2000)],
          ["task 2 end", be_within(50).of(2100)]
        )
      end
    end

    shared_examples :changes_task_execution_to_window_3 do
      it "changes task execution to new window" do
        expect(task_stats).to contain_exactly(
          ["task 0 start", 0],
          ["task 0 end", be_within(50).of(100)],
          # Limiter window changed
          ["task 1 start", be_within(50).of(3000)],
          ["task 1 end", be_within(50).of(3100)],
          ["task 2 start", be_within(50).of(6000)],
          ["task 2 end", be_within(50).of(6100)]
        )

        expect(limiter).to have_attributes(
          limit: limit,
          window: new_window
        )
      end
    end

    context "when update happens before tasks" do
      before do # must run before :async_processing context
        limiter.window = new_window
      end

      let(:task_duration) { 0.1 }
      let(:repeats) { 3 }

      include_context :async_processing

      context "when window is shrinked" do
        let(:new_window) { 1 }

        include_examples :changes_task_execution_to_window_1
      end

      context "when window is prolonged" do
        let(:new_window) { 3 }

        include_examples :changes_task_execution_to_window_3
      end
    end

    context "when update happens while existing tasks run" do
      before do # must run before :async_processing context
        Async::Task.current.async do |task|
          task.sleep(0.5)
          limiter.window = new_window
        end
      end

      let(:task_duration) { 0.1 }
      let(:repeats) { 3 }

      include_context :async_processing

      context "when window is shrinked" do
        let(:new_window) { 1 }

        include_examples :changes_task_execution_to_window_1
      end

      context "when window is prolonged" do
        let(:new_window) { 3 }

        include_examples :changes_task_execution_to_window_3
      end
    end
  end
end
