module Pay
  module Paddle
    class Charge
      attr_reader :pay_charge

      delegate :processor_id, :customer, to: :pay_charge

      def initialize(pay_charge)
        @pay_charge = pay_charge
      end

      def self.sync(charge_id, object: nil, try: 0, retries: 1)
        # Skip loading the latest charge details from the API if we already have it
        object ||= ::Paddle::Transaction.retrieve(id: charge_id)

        # Ignore charges without a Customer
        return if object.customer_id.blank?

        # Ignore transactions that are drafts
        return if object.status == "draft"

        pay_customer = Pay::Customer.find_by(processor: :paddle, processor_id: object.customer_id)
        return unless pay_customer

        # Ignore transactions that are payment method changes
        # But update the customer's payment method
        if object.origin == "subscription_payment_method_change"
          Pay::Paddle::PaymentMethod.sync(pay_customer: pay_customer, attributes: object.payments.first)
          return
        end

        item = object.items.first
        payment = object.payments.first
        price = item.price.unit_price
        if object.details.line_items
          metadata = object.details.line_items.first.id
        end

        attrs = {}

        details = payment.method_details

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

        attrs[:metadata] = metadata
        attrs[:amount] = payment.amount
        attrs[:created_at] = object.created_at
        attrs[:currency] = price.currency_code
        attrs[:subscription] = pay_customer.subscriptions.find_by(processor_id: object.subscription_id)

        # Update customer's payment method
        Pay::Paddle::PaymentMethod.sync(pay_customer: pay_customer, attributes: object.payments.first)

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

      # def charge
      #   return unless customer.subscription
      #   payments = PaddlePay::Subscription::Payment.list({subscription_id: customer.subscription.processor_id})
      #   charges = payments.select { |p| p[:id].to_s == processor_id }
      #   charges.try(:first)
      # rescue ::PaddlePay::PaddlePayError => e
      #   raise Pay::Paddle::Error, e
      # end

      # def refund!(amount_to_refund)
      #   return unless customer.subscription
      #   payments = PaddlePay::Subscription::Payment.list({subscription_id: customer.subscription.processor_id, is_paid: 1})
      #   if payments.count > 0
      #     PaddlePay::Subscription::Payment.refund(payments.last[:id], {amount: amount_to_refund})
      #     pay_charge.update(amount_refunded: amount_to_refund)
      #   else
      #     raise Error, "Payment not found"
      #   end
      # rescue ::PaddlePay::PaddlePayError => e
      #   raise Pay::Paddle::Error, e
      # end
    end
  end
end
