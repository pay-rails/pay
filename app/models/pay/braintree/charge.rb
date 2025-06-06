module Pay
  module Braintree
    class Charge < Pay::Charge
      def self.sync(charge_id, object: nil, try: 0, retries: 1)
        object ||= Pay.braintree_gateway.transaction.find(charge_id)

        pay_customer = Pay::Customer.find_by(processor: :braintree, processor_id: object.customer_details.id)
        return unless pay_customer

        pay_customer.save_transaction(object)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        if try <= retries
          sleep 0.1
          retry
        else
          raise
        end
      end

      def api_record
        Pay.braintree_gateway.transaction.find(processor_id)
      rescue ::Braintree::Braintree::Error => e
        raise Pay::Braintree::Error, e
      end

      def refund!(amount_to_refund = nil)
        amount_to_refund ||= amount
        Pay.braintree_gateway.transaction.refund(processor_id, amount_to_refund / 100.0)
        update(amount_refunded: amount_to_refund)
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_braintree_charge, Pay::Braintree::Charge
