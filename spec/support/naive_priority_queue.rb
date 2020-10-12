class NaivePriorityQueue
  include Enumerable

  def initialize
    @queue = []
  end

  def push(value, priority)
    @queue << Element.new(value, priority)
  end

  def shift
    return if @queue.empty?

    last_element_index = @queue.size - 1
    @queue.sort!
    element = @queue.delete_at(last_element_index)
    element.value
  end

  def each(...)
    @queue.each(...)
  end

  def delete(value)
    @queue.delete_if { |element| element.value == value }
  end

  class Element
    include Comparable

    attr_reader :value
    attr_reader :priority

    def initialize(value, priority)
      @value = value
      @priority = priority
    end

    def <=>(other)
      @priority <=> other.priority
    end
  end
end
