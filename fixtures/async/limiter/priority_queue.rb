# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2025, by Samuel Williams.

require "io/event"

# A priority queue wrapper that works with the test expectations
class TestPriorityQueue
	include Enumerable
	
	def initialize
		@heap = IO::Event::PriorityHeap.new
		@items = {} # Track items with their priorities for delete operation
	end
	
	def push(value, priority)
		# IO::Event::PriorityHeap is a min-heap, but we want higher priorities first, so we negate the priority to simulate max-heap behavior:
		@heap.push(value, -priority)
		@items[value] = -priority
	end
	
	def shift
		return nil if @heap.empty?
		
		value = @heap.pop
		@items.delete(value)
		value
	end
	
	def delete(value)
		return unless @items.key?(value)
		
		# Rebuild heap without the deleted value
		items_to_restore = @items.reject {|k, v| k == value}
		@items.clear
		@heap.clear
		
		items_to_restore.each do |val, neg_priority| 
			@heap.push(val, neg_priority)
			@items[val] = neg_priority
		end
		
		true
	end
	
	def each(&block)
		@items.keys.each(&block)
	end
	
	def empty?
		@heap.empty?
	end
end
