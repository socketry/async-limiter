module Async
  module Limiter
    module WindowOptions
      attr_reader :burstable

      attr_reader :release_required

      def initialize(*args, burstable: true, release_required: true, **options)
        super(*args, **options)

        @burstable = burstable
        @release_required = release_required

        @last_acquired_time = NULL_TIME
        @scheduled = !@burstable || !@release_required
      end

      def blocking?
        (@release_required && limit_blocking?) ||
          (@burstable ? window_blocking? : window_frame_blocking?)
      end

      def acquire
        super

        @last_acquired_time = Clock.now
      end

      def release
        if @release_required
          # We're resuming waiting fibers when lock is released.
          super
        else
          @count -= 1
        end
      end

      def limit=(...)
        super(...).tap do
          adjust_limit
        end
      end

      private

      # If @limit is a decimal number make it a whole number and adjust @window.
      def adjust_limit
        return if @limit.infinite?
        return if (@limit % 1).zero?

        case @limit
        when 0...1
          @window *= 1 / @limit
          @limit = 1
        when 1..
          if @window >= 2
            @window *= @limit.floor / @limit
            @limit = @limit.floor
          else
            @window *= @limit.ceil / @limit
            @limit = @limit.ceil
          end
        else
          raise "invalid limit #{@limit}"
        end

        window_updated
      end

      def window_frame_blocking?
        next_window_frame_start_time > Clock.now
      end

      def next_window_frame_start_time
        window_frame = @window.to_f / @limit
        @last_acquired_time + window_frame
      end

      def next_acquire_time
        if @burstable
          next_window_start_time
        else
          next_window_frame_start_time
        end
      end

      def window_updated
        raise NotImplementedError
      end
    end
  end
end
