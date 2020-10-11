require "async/task"

module Async
  module Limiter
    class Unlimited
      attr_reader :count

      def initialize(parent: nil)
        @count = 0
        @parent = parent
      end

      def limit
        Float::INFINITY
      end

      def blocking?
        false
      end

      def async(parent: (@parent || Task.current), **options)
        acquire
        parent.async(**options) do |task|
          yield task
        ensure
          release
        end
      end

      def sync(*queue_args, &block)
        acquire(*queue_args, &block)
      end

      def acquire
        @count += 1

        return unless block_given?

        begin
          yield
        ensure
          release
        end
      end

      def release
        @count -= 1
      end
    end
  end
end
