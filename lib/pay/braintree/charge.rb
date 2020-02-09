module Pay
  module Braintree
    module Charge
      extend ActiveSupport::Concern

      def braintree?
        processor == "braintree"
      end

      def braintree_charge
        Pay.braintree_gateway.transaction.find(processor_id)
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end

      def braintree_refund!(amount_to_refund)
        Pay.braintree_gateway.transaction.refund(processor_id, amount_to_refund / 100.0)

        update(amount_refunded: amount_to_refund)
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end
    end
  end
end
