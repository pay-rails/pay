module Pay
  module Braintree
    class Charge
      attr_reader :pay_charge

      delegate :processor_id, to: :pay_charge

      def initialize(pay_charge)
        @pay_charge = pay_charge
      end

      def charge
        Pay.braintree_gateway.transaction.find(processor_id)
      rescue ::Braintree::Braintree::Error => e
        raise Pay::Braintree::Error, e
      end

      def refund!(amount_to_refund)
        Pay.braintree_gateway.transaction.refund(processor_id, amount_to_refund / 100.0)
        pay_charge.update(amount_refunded: amount_to_refund)
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end
    end
  end
end
