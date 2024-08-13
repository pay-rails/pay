module Pay
  module LemonSqueezy
    class Charge < Pay::Charge
      # LemonSqueezy uses Order for one-time payments and Order + Subscription + SubscriptionInvoice for subscriptions

      def self.sync_order(order_id, object: nil, try: 0, retries: 1)
        object ||= ::LemonSqueezy::Order.retrieve(id: order_id)

        pay_customer = Pay::Customer.find_by(type: "Pay::LemonSqueezy::Customer", processor_id: object.customer_id)
        return unless pay_customer

        processor_id = "order:#{object.id}"
        attributes = {
          processor_id: processor_id,
          currency: object.currency,
          subtotal: object.subtotal,
          tax: object.tax,
          amount: object.total,
          amount_refunded: object.refunded_amount,
          created_at: (object.created_at ? Time.parse(object.created_at) : nil),
          updated_at: (object.updated_at ? Time.parse(object.updated_at) : nil)
        }

        # Update or create the charge
        if (pay_charge = pay_customer.charges.find_by(processor_id: processor_id))
          pay_charge.with_lock do
            pay_charge.update!(attributes)
          end
          pay_charge
        else
          pay_customer.charges.create!(attributes.merge(processor_id: processor_id))
        end
      end

      def self.sync_subscription_invoice(subscription_invoice_id, object: nil)
        # Skip loading the latest subscription invoice details from the API if we already have it
        object ||= ::LemonSqueezy::SubscriptionInvoice.retrieve(id: subscription_invoice_id)

        pay_customer = Pay::Customer.find_by(type: "Pay::LemonSqueezy::Customer", processor_id: object.customer_id)
        return unless pay_customer

        processor_id = "subscription_invoice:#{object.id}"
        subscription = Pay::LemonSqueezy::Subscription.find_by(processor_id: object.subscription_id)
        attributes = {
          processor_id: processor_id,
          currency: object.currency,
          amount: object.total,
          amount_refunded: object.refunded_amount,
          subtotal: object.subtotal,
          tax: object.tax,
          subscription: subscription,
          payment_method_type: ("card" if object.card_brand.present?),
          brand: object.card_brand,
          last4: object.card_last_four,
          created_at: (object.created_at ? Time.parse(object.created_at) : nil),
          updated_at: (object.updated_at ? Time.parse(object.updated_at) : nil)
        }

        # Update customer's payment method
        Pay::LemonSqueezy::PaymentMethod.sync(pay_customer: pay_customer, attributes: object)

        # Update or create the charge
        if (pay_charge = pay_customer.charges.find_by(processor_id: processor_id))
          pay_charge.with_lock do
            pay_charge.update!(attributes)
          end
          pay_charge
        else
          pay_customer.charges.create!(attributes.merge(processor_id: processor_id))
        end
      end

      def api_record
        ls_type, ls_id = processor_id.split(":", 2)
        case ls_type
        when "order"
          ::LemonSqueezy::Order.retrieve(id: ls_id)
        when "subscription_invoice"
          ::LemonSqueezy::SubscriptionInvoice.retrieve(id: ls_id)
        end
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end
    end
  end
end
