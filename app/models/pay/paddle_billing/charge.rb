module Pay
  module PaddleBilling
    class Charge < Pay::Charge
      extend Pay::Sync

      store_accessor :data, :paddle_receipt_url

      def self.sync(charge_id, object: nil)
        sync_with_retries do
          transaction = object || ::Paddle::Transaction.retrieve(id: charge_id)

          # Ignore transactions that aren't completed
          return unless transaction.status == "completed"
          return unless (pay_customer = find_pay_customer(transaction.customer_id))

          # Ignore transactions that are payment method changes
          # But update the customer's payment method
          if transaction.origin == "subscription_payment_method_change"
            Pay::PaddleBilling::PaymentMethod.sync(pay_customer: pay_customer, attributes: transaction.payments.first)
            return
          end

          attrs = {
            amount: transaction.details.totals.grand_total,
            created_at: transaction.created_at,
            currency: transaction.currency_code,
            metadata: transaction.details.line_items&.first&.id,
            subscription: pay_customer.subscriptions.find_by(processor_id: transaction.subscription_id)
          }

          if (details = Array.wrap(transaction.payments).first&.method_details)
            case details.type.downcase
            when "card"
              attrs[:payment_method_type] = "card"
              attrs[:brand] = details.card.type
              attrs[:exp_month] = details.card.expiry_month
              attrs[:exp_year] = details.card.expiry_year
              attrs[:last4] = details.card.last4
            when "paypal"
              attrs[:payment_method_type] = "paypal"
            end

            # Update customer's payment method
            Pay::PaddleBilling::PaymentMethod.sync(pay_customer: pay_customer, attributes: transaction.payments.first)
          end

          # Update or create the charge
          if (pay_charge = find_by(customer: pay_customer, processor_id: transaction.id))
            pay_charge.with_lock { pay_charge.update!(attrs) }
            pay_charge
          else
            create!(attrs.merge(customer: pay_customer, processor_id: transaction.id))
          end
        end
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_paddle_billing_charge, Pay::PaddleBilling::Charge
