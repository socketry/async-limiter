RSpec.shared_examples :set_decimal_limit_burstable do
  describe "#limit=" do
    context "when new limit is a decimal number" do
      let(:repeats) { 3 }
      let(:task_duration) { 0.1 }
      before do # must run before :async_processing context
        limiter.limit = new_limit
      end

      include_context :async_processing

      context "smaller than 1" do
        let(:new_window) { window.to_f * 1 / new_limit }
        let(:new_limit) { 0.5 }

        context "when starting limit is 1" do
          let(:limit) { 1 }

          it "sets limit to 1 and window to 2" do
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

        context "when starting limit is 3" do
          let(:limit) { 3 }

          it "sets limit to 1 and window to 2" do
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
      end

      context "greater than 1" do
        let(:new_limit) { 1.5 }
        let(:repeats) { 4 }

        context "when window is 1" do
          let(:new_window) { window.to_f * new_limit.ceil / new_limit }

          context "when starting limit is 1" do
            let(:limit) { 1 }

            it "sets limit to 2 and window to 1.33" do
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

          context "when starting limit is 3" do
            let(:limit) { 3 }

            it "sets limit to 2 and window to 1.33" do
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
        end

        context "when window is 3" do
          let(:window) { 3 }
          let(:new_window) { window.to_f * new_limit.floor / new_limit }

          context "when starting limit is 1" do
            let(:limit) { 1 }

            it "sets limit to 1 and window to 2" do
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

          context "when starting limit is 3" do
            let(:limit) { 3 }

            it "sets limit to 1 and window to 2" do
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

      context "smaller than 1" do
        let(:new_window) { window.to_f * 1 / new_limit }
        let(:new_limit) { 0.5 }

        context "when starting limit is 1" do
          let(:limit) { 1 }

          it "sets limit to 1 and window to 2" do
            expect(new_window).to eq 2

            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", be_within(50).of(new_window * 1000)], # 2000
              ["task 1 end", be_within(50).of(new_window * 1000 + 100)],
              ["task 2 start", be_within(50).of(new_window * 2000)], # 4000
              ["task 2 end", be_within(50).of(new_window * 2000 + 100)]
            )
          end
        end

        context "when starting limit is 3" do
          let(:limit) { 3 }

          it "sets limit to 1 and window to 2" do
            expect(new_window).to eq 2

            expect(task_stats).to contain_exactly(
              ["task 0 start", 0],
              ["task 0 end", be_within(50).of(100)],
              ["task 1 start", be_within(50).of(new_window * 1000)], # 2000
              ["task 1 end", be_within(50).of(new_window * 1000 + 100)],
              ["task 2 start", be_within(50).of(new_window * 2000)], # 4000
              ["task 2 end", be_within(50).of(new_window * 2000 + 100)]
            )
          end
        end
      end

      context "greater than 1" do
        let(:new_limit) { 1.5 }
        let(:repeats) { 4 }

        context "when window is 1" do
          let(:new_window) { window.to_f * new_limit.ceil / new_limit }

          context "when starting limit is 1" do
            let(:limit) { 1 }

            it "sets limit to 2 and window to 1.33" do
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

          context "when starting limit is 3" do
            let(:limit) { 3 }

            it "sets limit to 2 and window to 1.33" do
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
        end

        context "when window is 3" do
          let(:window) { 3 }
          let(:new_window) { window.to_f * new_limit.floor / new_limit }

          context "when starting limit is 1" do
            let(:limit) { 1 }

            it "sets limit to 1 and window to 2" do
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

          context "when starting limit is 3" do
            let(:limit) { 3 }

            it "sets limit to 1 and window to 2" do
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
        end
      end
    end
  end
end
