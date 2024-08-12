module Pay
  module FakeProcessor
    class PaymentMethod < Pay::PaymentMethod
      def make_default!
      end

      def detach
      end
    end
  end
end
