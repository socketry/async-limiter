require_relative "window"

module Async
  module Limiter
    # Ensures units are acquired during the time window.
    # Example: You can perform N operations at 10:10:10.999, and then can
    # perform another N operations at 10:10:11.000.
    class FixedWindow < Window
      def initialize(*args, **options)
        raise "Don't specify :type with #{self.class}" if options[:type]

        super(*args, type: :fixed, **options)
      end
    end
  end
end
