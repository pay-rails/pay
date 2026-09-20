module Pay
  module LemonSqueezy
    class Charge < Pay::Charge
      extend Pay::Sync

      # LemonSqueezy uses Order for one-time payments and Order + Subscription + SubscriptionInvoice for subscriptions
      # Charges are stored with a "order:123" or "subscription_invoice:123" processor_id so both can be synced by ID

      def self.sync(processor_id, object: nil)
        type, id = processor_id.split(":", 2)
        case type
        when "order"
          sync_order(id, object: object)
        when "subscription_invoice"
          sync_subscription_invoice(id, object: object)
        end
      end

      def self.sync_order(order_id, object: nil)
        sync_with_retries do
          order = object || ::LemonSqueezy::Order.retrieve(id: order_id)
          return unless (pay_customer = find_pay_customer(order.customer_id))

          processor_id = "order:#{order.id}"
          attributes = {
            processor_id: processor_id,
            currency: order.currency,
            subtotal: order.subtotal,
            tax: order.tax,
            amount: order.total,
            amount_refunded: order.refunded_amount,
            created_at: (order.created_at ? Time.parse(order.created_at) : nil),
            updated_at: (order.updated_at ? Time.parse(order.updated_at) : nil)
          }

          # Update or create the charge
          if (pay_charge = find_by(customer: pay_customer, processor_id: processor_id))
            pay_charge.with_lock { pay_charge.update!(attributes) }
            pay_charge
          else
            create!(attributes.merge(customer: pay_customer, processor_id: processor_id))
          end
        end
      end

      def self.sync_subscription_invoice(subscription_invoice_id, object: nil)
        sync_with_retries do
          invoice = object || ::LemonSqueezy::SubscriptionInvoice.retrieve(id: subscription_invoice_id)
          return unless (pay_customer = find_pay_customer(invoice.customer_id))

          processor_id = "subscription_invoice:#{invoice.id}"
          subscription = Pay::LemonSqueezy::Subscription.find_by(processor_id: invoice.subscription_id)
          attributes = {
            processor_id: processor_id,
            currency: invoice.currency,
            amount: invoice.total,
            amount_refunded: invoice.refunded_amount,
            subtotal: invoice.subtotal,
            tax: invoice.tax,
            subscription: subscription,
            payment_method_type: ("card" if invoice.card_brand.present?),
            brand: invoice.card_brand,
            last4: invoice.card_last_four,
            created_at: (invoice.created_at ? Time.parse(invoice.created_at) : nil),
            updated_at: (invoice.updated_at ? Time.parse(invoice.updated_at) : nil)
          }

          # Update customer's payment method
          Pay::LemonSqueezy::PaymentMethod.sync(pay_customer: pay_customer, attributes: invoice)

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

ActiveSupport.run_load_hooks :pay_lemon_squeezy_charge, Pay::LemonSqueezy::Charge
