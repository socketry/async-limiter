RSpec.shared_examples :set_decimal_limit_smaller_than_1 do
  context "smaller than 1" do
    let(:new_window) { window.to_f * 1 / new_limit }
    let(:new_limit) { 0.5 }

    shared_examples :sets_limit_1_window_2 do
      it "changes effective limit to 1 and window to 2" do
        expect(limiter).to have_attributes(
          limit: new_limit,
          window: window
        )
        expect(new_window).to eq 2

        expect(task_stats).to contain_exactly(
          ["task 0 start", 0],
          ["task 0 end", be_within(50).of(100)],
          ["task 1 start", be_within(50).of(new_window * 1000)], # 2000
          ["task 1 end", be_within(50).of(new_window * 1000 + 100)],
          ["task 2 start", be_within(50).of(new_window * 1000 * 2)], # 4000
          ["task 2 end", be_within(50).of(new_window * 1000 * 2 + 100)]
        )
      end
    end

    context "when starting limit is 1" do
      let(:limit) { 1 }

      include_examples :sets_limit_1_window_2
    end

    context "when starting limit is 3" do
      let(:limit) { 3 }

      include_examples :sets_limit_1_window_2
    end
  end
end

RSpec.shared_examples :set_decimal_limit_greater_than_1_window_3 do
  context "when window is 3" do
    let(:window) { 3 }
    let(:new_window) { window.to_f * new_limit.floor / new_limit }

    shared_examples :sets_limit_1_window_2 do
      it "changes effective limit to 1 and window to 2" do
        expect(limiter).to have_attributes(
          limit: new_limit,
          window: window
        )
        expect(new_window).to eq 2

        expect(task_stats).to contain_exactly(
          ["task 0 start", 0],
          ["task 0 end", be_within(50).of(100)],
          ["task 1 start", be_within(50).of(new_window * 1000)], # 2000
          ["task 1 end", be_within(50).of(new_window * 1000 + 100)],
          ["task 2 start", be_within(50).of(new_window * 2000)], # 4000
          ["task 2 end", be_within(50).of(new_window * 2000 + 100)],
          ["task 3 start", be_within(50).of(new_window * 3000)], # 6000
          ["task 3 end", be_within(50).of(new_window * 3000 + 100)]
        )
      end
    end

    context "when starting limit is 1" do
      let(:limit) { 1 }

      include_examples :sets_limit_1_window_2
    end

    context "when starting limit is 3" do
      let(:limit) { 3 }

      include_examples :sets_limit_1_window_2
    end
  end
end

RSpec.shared_examples :set_decimal_limit_burstable do
  describe "#limit=" do
    context "when new limit is a decimal number" do
      let(:repeats) { 3 }
      let(:task_duration) { 0.1 }
      before do # must run before :async_processing context
        limiter.limit = new_limit
      end

      include_context :async_processing

      include_examples :set_decimal_limit_smaller_than_1

      context "greater than 1" do
        let(:new_limit) { 1.5 }
        let(:repeats) { 4 }

        include_examples :set_decimal_limit_greater_than_1_window_3

        context "when window is 1" do
          let(:new_window) { window.to_f * new_limit.ceil / new_limit }

          shared_examples :sets_limit_2_window_1_33 do
            it "changes effective limit to 2 and window to 1.33" do
              expect(limiter).to have_attributes(
                limit: new_limit,
                window: window
              )
              expect(new_window.truncate(2)).to eq 1.33

              expect(task_stats).to contain_exactly(
                ["task 0 start", 0],
                ["task 0 end", be_within(50).of(100)],
                ["task 1 start", 0],
                ["task 1 end", be_within(50).of(100)],
                ["task 2 start", be_within(50).of(new_window * 1000)], # 1333
                ["task 2 end", be_within(50).of(new_window * 1000 + 100)],
                ["task 3 start", be_within(50).of(new_window * 1000)], # 1333
                ["task 3 end", be_within(50).of(new_window * 1000 + 100)]
              )
            end
          end

          context "when starting limit is 1" do
            let(:limit) { 1 }

            include_examples :sets_limit_2_window_1_33
          end

          context "when starting limit is 3" do
            let(:limit) { 3 }

            include_examples :sets_limit_2_window_1_33
          end
        end
      end
    end

    context "while existing tasks run" do
      let(:task_duration) { 0.1 }

      require "async/limiter/window/fixed"

      before do # must run before :async_processing context
        Async::Task.current.async do |task|
          delay = if described_class == Async::Limiter::Window::Fixed
            next_fixed_window_start_time - Async::Clock.now
          else
            0
          end
          task.sleep(delay + update_limit_after)
          limiter.limit = new_limit
        end
      end

      include_context :async_processing

      context "smaller than 1" do
        let(:new_window) { window.to_f * 1 / new_limit }
        let(:new_limit) { 0.5 }

        context "when starting limit is 1" do
          let(:limit) { 1 }
          let(:repeats) { 4 }
          let(:update_limit_after) { 2.2 }

          it "changes effective limit to 1 and window to 2" do
            expect(new_window).to eq 2

            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", be_within(50).of(1000)],
              ["task 1 end", be_within(50).of(1000 + 100)],
              # Limiter updated, effective limit is 1, window is 2.
              ["task 2 start", be_within(50).of(2000)],
              ["task 2 end", be_within(50).of(2000 + 100)],
              ["task 3 start", be_within(50).of(4000)],
              ["task 3 end", be_within(50).of(4000 + 100)]
            )

            expect(limiter).to have_attributes(
              limit: new_limit,
              window: window
            )
          end
        end

        context "when starting limit is 3" do
          let(:limit) { 3 }
          let(:repeats) { 5 }
          let(:update_limit_after) { 0.5 }

          it "changes effective limit to 1 and window to 2" do
            expect(new_window).to eq 2

            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", 0],
              ["task 1 end", be_within(50).of(100)],
              ["task 2 start", 0],
              ["task 2 end", be_within(50).of(100)],
              # Limiter updated, effective limit is 1, window is 2.
              ["task 3 start", be_within(50).of(2000)],
              ["task 3 end", be_within(50).of(2000 + 100)],
              ["task 4 start", be_within(50).of(4000)],
              ["task 4 end", be_within(50).of(4000 + 100)]
            )

            expect(limiter).to have_attributes(
              limit: new_limit,
              window: window
            )
          end
        end
      end

      context "greater than 1" do
        let(:new_limit) { 1.5 }

        context "when window is 1" do
          let(:new_window) { window.to_f * new_limit.ceil / new_limit }

          context "when starting limit is 1" do
            let(:limit) { 1 }
            let(:repeats) { 5 }
            let(:update_limit_after) { 0.5 }
            # prevent intermittent spec failures
            let(:next_fixed_window_start_time) do
              # Multiplier of both 2 and 1.33 (old and new window). By waiting
              # for this window, both old and new window start at the same time.
              window = 4
              window_index = (Async::Clock.now / window).floor
              window_index.next * window
            end

            it "changes effective limit to 2 and window to 1.33" do
              expect(new_window.truncate(2)).to eq 1.33

              expect(task_stats).to contain_exactly(
                ["task 0 start", 0],
                ["task 0 end", be_within(50).of(100)],
                # Limiter updated, effective limit is 2, window is 1.33.
                ["task 1 start", be_within(50).of(500)],
                ["task 1 end", be_within(50).of(600)],
                ["task 2 start", be_within(50).of(1333)],
                ["task 2 end", be_within(50).of(1333 + 100)],
                ["task 3 start", be_within(50).of(1333)],
                ["task 3 end", be_within(50).of(1333 + 100)],
                ["task 4 start", be_within(50).of(2666)],
                ["task 4 end", be_within(50).of(2666 + 100)]
              )

              expect(limiter).to have_attributes(
                limit: new_limit,
                window: window
              )
            end
          end

          context "when starting limit is 3" do
            let(:limit) { 3 }
            let(:repeats) { 9 }
            let(:update_limit_after) { 0.5 }
            # prevent intermittent spec failures
            let(:next_fixed_window_start_time) do
              # Multiplier of both 2 and 1.33 (old and new window). By waiting
              # for this window, both old and new window start at the same time.
              window = 4
              window_index = (Async::Clock.now / window).floor
              window_index.next * window
            end

            it "changes effective limit to 2 and window to 1.33" do
              expect(new_window.truncate(2)).to eq 1.33

              expect(task_stats).to contain_exactly(
                ["task 0 start", 0],
                ["task 0 end", be_within(50).of(100)],
                ["task 1 start", 0],
                ["task 1 end", be_within(50).of(100)],
                ["task 2 start", 0],
                ["task 2 end", be_within(50).of(100)],
                # Limiter updated, effective limit is 2, window is 1.33.
                ["task 3 start", be_within(50).of(1333)],
                ["task 3 end", be_within(50).of(1333 + 100)],
                ["task 4 start", be_within(50).of(1333)],
                ["task 4 end", be_within(50).of(1333 + 100)],
                ["task 5 start", be_within(50).of(2666)],
                ["task 5 end", be_within(50).of(2666 + 100)],
                ["task 6 start", be_within(50).of(2666)],
                ["task 6 end", be_within(50).of(2666 + 100)],
                ["task 7 start", be_within(50).of(3999)],
                ["task 7 end", be_within(50).of(3999 + 100)],
                ["task 8 start", be_within(50).of(3999)],
                ["task 8 end", be_within(50).of(3999 + 100)]
              )

              expect(limiter).to have_attributes(
                limit: new_limit,
                window: window
              )
            end
          end
        end

        context "when window is 3" do
          let(:window) { 3 }
          let(:new_window) { window.to_f * new_limit.floor / new_limit }

          context "when starting limit is 1" do
            let(:limit) { 1 }
            let(:repeats) { 3 }
            let(:update_limit_after) { 0.5 }

            it "changes effective limit to 1 and window to 2" do
              expect(new_window).to eq 2

              expect(task_stats).to contain_exactly(
                ["task 0 start", 0],
                ["task 0 end", be_within(50).of(100)],
                # Limiter updated, effective limit is 1, window is 2.
                ["task 1 start", be_within(50).of(2000)],
                ["task 1 end", be_within(50).of(2000 + 100)],
                ["task 2 start", be_within(50).of(4000)],
                ["task 2 end", be_within(50).of(4000 + 100)]
              )

              expect(limiter).to have_attributes(
                limit: new_limit,
                window: window
              )
            end
          end

          context "when starting limit is 3" do
            let(:limit) { 3 }
            let(:repeats) { 5 }
            let(:update_limit_after) { 0.5 }

            it "changes effective limit to 1 and window to 2" do
              expect(new_window).to eq 2

              expect(task_stats).to contain_exactly(
                ["task 0 start", 0],
                ["task 0 end", be_within(50).of(100)],
                ["task 1 start", 0],
                ["task 1 end", be_within(50).of(100)],
                ["task 2 start", 0],
                ["task 2 end", be_within(50).of(100)],
                # Limiter updated, effective limit is 1, window is 2.
                ["task 3 start", be_within(50).of(2000)],
                ["task 3 end", be_within(50).of(2000 + 100)],
                ["task 4 start", be_within(50).of(4000)],
                ["task 4 end", be_within(50).of(4000 + 100)]
              )

              expect(limiter).to have_attributes(
                limit: new_limit,
                window: window
              )
            end
          end
        end
      end
    end
  end
end

RSpec.shared_examples :set_decimal_limit_non_burstable do
  describe "#limit=" do
    context "when new limit is a decimal number" do
      let(:repeats) { 3 }
      let(:task_duration) { 0.1 }
      before do # must run before :async_processing context
        limiter.limit = new_limit
      end

      include_context :async_processing

      include_examples :set_decimal_limit_smaller_than_1

      context "greater than 1" do
        let(:new_limit) { 1.5 }
        let(:repeats) { 4 }

        include_examples :set_decimal_limit_greater_than_1_window_3

        context "when window is 1" do
          let(:new_window) { window.to_f * new_limit.ceil / new_limit }

          shared_examples :sets_limit_2_window_1_33 do
            it "changes effective limit to 2 and window to 1.33" do
              expect(limiter).to have_attributes(
                limit: new_limit,
                window: window
              )
              expect(new_window.truncate(2)).to eq 1.33

              expect(task_stats).to contain_exactly(
                ["task 0 start", 0],
                ["task 0 end", be_within(50).of(100)],
                ["task 1 start", be_within(50).of(666)],
                ["task 1 end", be_within(50).of(766)],
                ["task 2 start", be_within(50).of(new_window * 1000)], # 1333
                ["task 2 end", be_within(50).of(new_window * 1000 + 100)],
                ["task 3 start", be_within(50).of(new_window * 1000 + 666)],
                ["task 3 end", be_within(50).of(new_window * 1000 + 766)]
              )
            end
          end

          context "when starting limit is 1" do
            let(:limit) { 1 }

            include_examples :sets_limit_2_window_1_33
          end

          context "when starting limit is 3" do
            let(:limit) { 3 }

            include_examples :sets_limit_2_window_1_33
          end
        end
      end
    end

    context "while existing tasks run" do
      let(:task_duration) { 0.1 }

      before do # must run before :async_processing context
        Async::Task.current.async do |task|
          task.sleep(update_limit_after)
          limiter.limit = new_limit
        end
      end

      include_context :async_processing

      context "smaller than 1" do
        let(:new_window) { window.to_f * 1 / new_limit }
        let(:new_limit) { 0.5 }

        context "when starting limit is 1" do
          let(:limit) { 1 }
          let(:repeats) { 4 }
          let(:update_limit_after) { 2.2 }

          it "changes effective limit to 1 and window to 2" do
            expect(new_window).to eq 2

            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", be_within(50).of(1000)],
              ["task 1 end", be_within(50).of(1000 + 100)],
              # Limiter updated, effective limit is 1, window is 2.
              ["task 2 start", be_within(50).of(2000)],
              ["task 2 end", be_within(50).of(2000 + 100)],
              ["task 3 start", be_within(50).of(4000)],
              ["task 3 end", be_within(50).of(4000 + 100)]
            )

            expect(limiter).to have_attributes(
              limit: new_limit,
              window: window
            )
          end
        end

        context "when starting limit is 3" do
          let(:limit) { 3 }
          let(:repeats) { 4 }
          let(:update_limit_after) { 0.5 }

          it "changes effective limit to 1 and window to 2" do
            expect(new_window).to eq 2

            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", be_within(50).of(333)],
              ["task 1 end", be_within(50).of(433)],
              # Limiter updated, effective limit is 1, window is 2.
              ["task 2 start", be_within(50).of(2333)],
              ["task 2 end", be_within(50).of(2333 + 100)],
              ["task 3 start", be_within(50).of(4333)],
              ["task 3 end", be_within(50).of(4333 + 100)]
            )

            expect(limiter).to have_attributes(
              limit: new_limit,
              window: window
            )
          end
        end
      end

      context "greater than 1" do
        let(:new_limit) { 1.5 }

        context "when window is 1" do
          let(:new_window) { window.to_f * new_limit.ceil / new_limit }
          let(:new_window_frame) { 0.666 }

          context "when starting limit is 1" do
            let(:limit) { 1 }
            let(:repeats) { 3 }
            let(:update_limit_after) { 0.5 }

            it "changes effective limit to 2 and window to 1.33" do
              expect(new_window.truncate(2)).to eq 1.33

              expect(task_stats).to contain_exactly(
                ["task 0 start", 0],
                ["task 0 end", be_within(50).of(100)],
                # Limiter updated, effective limit is 2, window is 1.33.
                # Window frame is 666.
                ["task 1 start", be_within(50).of(new_window_frame * 1000)],
                ["task 1 end", be_within(50).of(new_window_frame * 1000 + 100)],
                ["task 2 start", be_within(50).of(new_window_frame * 2000)],
                ["task 2 end", be_within(50).of(new_window_frame * 2000 + 100)]
              )

              expect(limiter).to have_attributes(
                limit: new_limit,
                window: window
              )
            end
          end

          context "when starting limit is 3" do
            let(:limit) { 3 }
            let(:repeats) { 5 }
            let(:update_limit_after) { 0.5 }

            it "changes effective limit to 2 and window to 1.33" do
              expect(new_window.truncate(2)).to eq 1.33

              expect(task_stats).to contain_exactly(
                ["task 0 start", 0],
                ["task 0 end", be_within(50).of(100)],
                ["task 1 start", be_within(50).of(333)],
                ["task 1 end", be_within(50).of(333 + 100)],
                # Limiter updated, effective limit is 2, window is 1.33.
                # Window frame is 666.
                ["task 2 start", be_within(50).of(1000)],
                ["task 2 end", be_within(50).of(1000 + 100)],
                ["task 3 start", be_within(50).of(1666)],
                ["task 3 end", be_within(50).of(1666 + 100)],
                ["task 4 start", be_within(50).of(2333)],
                ["task 4 end", be_within(50).of(2333 + 100)]
              )

              expect(limiter).to have_attributes(
                limit: new_limit,
                window: window
              )
            end
          end
        end

        context "when window is 3" do
          let(:window) { 3 }
          let(:new_window) { window.to_f * new_limit.floor / new_limit }
          let(:new_window_frame) { 2 }

          shared_examples :changes_effective_limit_to_1_and_window_to_2 do
            let(:repeats) { 3 }
            let(:update_limit_after) { 1 }

            it "changes effective limit to 1 and window to 2" do
              expect(new_window).to eq 2

              expect(task_stats).to contain_exactly(
                ["task 0 start", 0],
                ["task 0 end", be_within(50).of(100)],
                # Limiter updated, effective limit is 1, window is 2,
                # window frame is 2.
                ["task 1 start", be_within(50).of(new_window_frame * 1000)],
                ["task 1 end", be_within(50).of(new_window_frame * 1000 + 100)],
                ["task 2 start", be_within(50).of(new_window_frame * 2000)],
                ["task 2 end", be_within(50).of(new_window_frame * 2000 + 100)]
              )

              expect(limiter).to have_attributes(
                limit: new_limit,
                window: window
              )
            end
          end

          context "when starting limit is 1" do
            let(:limit) { 1 }

            include_examples :changes_effective_limit_to_1_and_window_to_2
          end

          context "when starting limit is 3" do
            let(:limit) { 3 }

            include_examples :changes_effective_limit_to_1_and_window_to_2
          end
        end
      end
    end
  end
end
