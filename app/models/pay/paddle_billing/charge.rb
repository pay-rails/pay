module Pay
  module PaddleBilling
    class Charge < Pay::Charge
      store_accessor :data, :paddle_receipt_url

      def self.sync(charge_id, object: nil, try: 0, retries: 1)
        # Skip loading the latest charge details from the API if we already have it
        object ||= ::Paddle::Transaction.retrieve(id: charge_id)

        # Ignore transactions that aren't completed
        return unless object.status == "completed"

        # Ignore charges without a Customer
        return if object.customer_id.blank?

        pay_customer = Pay::Customer.find_by(processor: :paddle_billing, processor_id: object.customer_id)
        return unless pay_customer

        # Ignore transactions that are payment method changes
        # But update the customer's payment method
        if object.origin == "subscription_payment_method_change"
          Pay::PaddleBilling::PaymentMethod.sync(pay_customer: pay_customer, attributes: object.payments.first)
          return
        end

        attrs = {
          amount: object.details.totals.grand_total,
          created_at: object.created_at,
          currency: object.currency_code,
          metadata: object.details.line_items&.first&.id,
          subscription: pay_customer.subscriptions.find_by(processor_id: object.subscription_id)
        }

        if (details = Array.wrap(object.payments).first&.method_details)
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
          Pay::PaddleBilling::PaymentMethod.sync(pay_customer: pay_customer, attributes: object.payments.first)
        end

        # Update or create the charge
        if (pay_charge = pay_customer.charges.find_by(processor_id: object.id))
          pay_charge.with_lock do
            pay_charge.update!(attrs)
          end
          pay_charge
        else
          pay_customer.charges.create!(attrs.merge(processor_id: object.id))
        end
      end
    end
  end
end
