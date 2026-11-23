module Pay
  module Braintree
    class Charge < Pay::Charge
      extend Pay::Sync

      def self.sync(charge_id, object: nil)
        sync_with_retries do
          transaction = object || Pay.braintree_gateway.transaction.find(charge_id)
          return unless (pay_customer = find_pay_customer(transaction.customer_details.id))

          pay_customer.save_transaction(transaction)
        end
      end

      def api_record
        Pay.braintree_gateway.transaction.find(processor_id)
      rescue ::Braintree::Braintree::Error => e
        raise Pay::Braintree::Error, e
      end

      def refund!(amount_to_refund = nil)
        amount_to_refund ||= amount - amount_refunded.to_i
        result = Pay.braintree_gateway.transaction.refund(processor_id, Pay::Currency.from_subunit(amount_to_refund, currency: currency))
        raise Pay::Braintree::Error, result unless result.success?

        update(amount_refunded: amount_refunded.to_i + amount_to_refund)
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_braintree_charge, Pay::Braintree::Charge
