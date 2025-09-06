# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2025, by Samuel Williams.

require_relative "priority_queue"

module Async
	module Limiter
		CustomQueueTest = Sus::Shared("custom queue test") do
			let(:repeats) {4}
			let(:task_duration) {0.1}
			let(:result) {[]}
			
			let(:limiter) do
				subject.new(limit, queue: TestPriorityQueue.new)
			end
			
			with "#async" do
				before do
					repeats.times.map {|i|
						Async::Task.current.async do
							limiter.async(i) {|task|
								task.sleep(task_duration)
								result << i
							}.wait
						end
					}.map(&:wait)
				end
				
				it "runs tasks based on the priority" do
					expect(result).to be == [0, 3, 2, 1]
				end
			end
			
			with "#sync" do
				before do
					repeats.times.map {|i|
						Async::Task.current.async do
							limiter.sync(i) do |task|
								task.sleep(task_duration)
								result << i
							end
						end
					}.map(&:wait)
				end
				
				it "runs tasks based on the priority" do
					expect(result).to be == [0, 3, 2, 1]
				end
			end
			
			with "#acquire" do
				before do
					repeats.times.map {|i|
						Async::Task.current.async do |task|
							limiter.acquire(i)
							task.sleep(task_duration)
							result << i
							limiter.release
						end
					}.map(&:wait)
				end
				
				it "runs tasks based on the priority" do
					expect(result).to be == [0, 3, 2, 1]
				end
			end
		end
	end
end
