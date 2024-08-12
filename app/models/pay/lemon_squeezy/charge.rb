module Pay
  module LemonSqueezy
    class Charge < Pay::Charge
      def self.sync(charge_id, object: nil, try: 0, retries: 1)
        # Skip loading the latest subscription invoice details from the API if we already have it
        object ||= ::LemonSqueezy::SubscriptionInvoice.retrieve(id: charge_id)

        attrs = object.data.attributes if object.respond_to?(:data)
        attrs ||= object

        # Ignore charges without a Customer
        return if attrs.customer_id.blank?

        pay_customer = Pay::Customer.find_by(processor: :lemon_squeezy, processor_id: attrs.customer_id)
        return unless pay_customer

        attributes = {
          amount: attrs.total,
          created_at: attrs.created_at,
          currency: attrs.currency,
          subscription: pay_customer.subscriptions.find_by(processor_id: attrs.subscription_id),
          payment_method_type: "card",
          brand: attrs.card_brand,
          last4: attrs.card_last_four
        }

        # Update customer's payment method
        Pay::LemonSqueezy::PaymentMethod.sync(pay_customer: pay_customer, attributes: attrs)

        # Update or create the charge
        if (pay_charge = pay_customer.charges.find_by(processor_id: charge_id))
          pay_charge.with_lock do
            pay_charge.update!(attributes)
          end
          pay_charge
        else
          pay_customer.charges.create!(attributes.merge(processor_id: charge_id))
        end
      end
    end
  end
end
