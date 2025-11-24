module Pay
  module Braintree
    class PaymentMethod < Pay::PaymentMethod
      def self.sync(id, object: nil, try: 0, retries: 1)
        object ||= Pay.braintree_gateway.payment_method.find(id)

        pay_customer = Pay::Braintree::Customer.find_by(processor_id: object.customer_id)
        return unless pay_customer

        pay_customer.save_payment_method(object, default: object.default?)
      end

      # Sets payment method as default
      def make_default!
        return if default?

        result = gateway.customer.update(customer.processor_id, default_payment_method_token: processor_id)
        raise Pay::Braintree::Error, result unless result.success?

        customer.payment_methods.update_all(default: false)
        update!(default: true)

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

ActiveSupport.run_load_hooks :pay_braintree_payment_method, Pay::Braintree::PaymentMethod
