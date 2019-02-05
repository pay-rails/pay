module Pay
  module Braintree

    module Charge
      extend ActiveSupport::Concern

      def braintree_charge
        Pay.braintree_gateway.transaction.find(processor_id)
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end

      def braintree_refund!(amount)
        Pay.braintree_gateway.transaction.refund(processor_id, amount / 100.0)
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end
    end

  end
end
