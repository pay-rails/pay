module Pay
  module Paddle
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method

      # Paddle doesn't provide PaymentMethod IDs, so we have to lookup via the Customer
      def self.sync(pay_customer:, attributes:)
        return unless pay_customer.subscription

        payment_method = pay_customer.default_payment_method || pay_customer.build_default_payment_method
        payment_method.processor_id ||= NanoId.generate

        payment_method.update!(attributes)
        payment_method
      end

      def initialize(pay_payment_method)
        @pay_payment_method = pay_payment_method
      end

      # Sets payment method as default
      def make_default!
      end

      # Remove payment method
      def detach
      end
    end
  end
end
