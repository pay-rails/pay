module Pay
  module Braintree
    class Error < Pay::Error
      def message
        result.message
      end
    end
  end
end
