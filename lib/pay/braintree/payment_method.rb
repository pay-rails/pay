module Pay
  module Braintree
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method

      def self.sync(id, object: nil, try: 0, retries: 1)
        object ||= gateway.payment_method.find(id)

        pay_customer = Pay::Customer.find_by(processor: :braintree, processor_id: object.customer_id)
        return unless pay_customer

        pay_customer.save_payment_method(object, default: object.default?)
      end

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
