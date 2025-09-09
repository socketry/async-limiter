# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Limiter
		ChainableAsync = Sus::Shared("chainable async") do
			# Simple chainable async test - just make sure it doesn't crash
			with "when parent is passed via #new" do
				it "chains async to parent" do
					parent = Async::Task.current
					test_subject = subject.new(parent: parent)
					
					test_subject.async do |task|
						expect(task).to be_a(Async::Task)
					end.wait
				end
			end
			
			with "when parent is passed via #async" do
				it "chains async to parent" do
					parent = Async::Task.current
					test_subject = subject.new
					
					test_subject.async(parent: parent) do |task|
						expect(task).to be_a(Async::Task)
					end.wait
				end
			end
		end
	end
end
