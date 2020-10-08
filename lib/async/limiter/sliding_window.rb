require_relative "window"

module Async
  module Limiter
    # Ensures units are acquired during the sliding time window.
    # Example: You can perform N operations at 10:10:10.999 but can't perform
    # another N operations until 10:10:11.999.
    class SlidingWindow < Window
      def initialize(*args, **options)
        raise "Don't specify :type with #{self.class}" if options[:type]

        super(*args, type: :sliding, **options)
      end
    end
  end
end
