module Pay
  module Braintree
    class PaymentMethod < Pay::PaymentMethod
      extend Pay::Sync

      def self.sync(id, object: nil)
        sync_with_retries do
          payment_method = object || Pay.braintree_gateway.payment_method.find(id)
          return unless (pay_customer = find_pay_customer(payment_method.customer_id))

          pay_customer.save_payment_method(payment_method, default: payment_method.default?)
        end
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
