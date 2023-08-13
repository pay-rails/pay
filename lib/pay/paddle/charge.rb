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

        # Ignore transactions that are payment method changes
        return if object.origin == "subscription_payment_method_change"

        pay_customer = Pay::Customer.find_by(processor: :paddle, processor_id: object.customer_id)
        return unless pay_customer

        if pay_customer.nil?
          owner = Pay::Paddle.owner_from_passthrough(event.custom_data.passthrough)
          pay_customer = owner&.set_payment_processor :paddle, processor_id: event.customer_id
        end

        if pay_customer.nil?
          Rails.logger.error("[Pay] Unable to find Pay::Customer with: '#{event.passthrough}'")
          return
        end

        item    = object.items.first
        payment = object.payments.first
        price   = item.price.unit_price
        card    = payment&.method_details&.card
        if object.details.line_items
          metadata = object.details.line_items.first.id
        end

        attrs = {
          amount: (price.amount.to_f / 100),
          created_at: object.created_at,
          currency: price.currency_code,
          brand: card.try(:type).to_s,
          exp_month: card.try(:exp_month).to_s,
          exp_year: card.try(:exp_year).to_s,
          last4: card.try(:last4).to_s,
          metadata: metadata,
          payment_method_type: payment&.method_details&.type,
          subscription: pay_customer.subscriptions.find_by(processor_id: object.subscription_id),
        }

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
