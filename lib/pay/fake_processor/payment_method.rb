module Pay
  module FakeProcessor
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method

      def initialize(pay_payment_method)
        @pay_payment_method = pay_payment_method
      end

      # Sets payment method as default on Stripe
      def make_default!
      end

      # Remove payment method
      def detach
      end
    end
  end
end
