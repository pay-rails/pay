module Pay
  module Braintree
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method

      def initialize(pay_payment_method)
        @pay_payment_method = pay_payment_method
      end

      # Sets payment method as default on Stripe
      def make_default!
        result = gateway.customer.update(customer.processor_id, default_payment_method_token: processor_id)
        raise Pay::Braintree::Error, result unless result.success?
        result.success?
      end

      # Remove payment method
      def detach
        result = gateway.payment_method.delete(processor_id)
        raise Pay::Braintree::Error, result unless result.success?
        result.success?
      end

      private

      def gateway
        Pay.braintree_gateway
      end
    end
  end
end
