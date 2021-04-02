module Pay
  module Braintree
    class Error < Pay::Error
      # For any manually raised Braintree error results (for failure responses)
      # we can raise this exception manually but treat it as if we wrapped an exception

      attr_reader :result

      def initialize(result)
        if result.is_a?(::Braintree::ErrorResult)
          super(result.message)
          @result = result
        else
          super
        end
      end

      def cause
        super || result
      end
    end
  end
end
