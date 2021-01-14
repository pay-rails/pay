module Pay
  module Paddle
    module Charge
      extend ActiveSupport::Concern

      included do
        scope :paddle, -> { where(processor: :paddle) }

        store_accessor :data, :paddle_receipt_url
      end

      def paddle?
        processor == "paddle"
      end

      def paddle_charge
        return unless owner.subscription
        payments = PaddlePay::Subscription::Payment.list({subscription_id: owner.subscription.processor_id})
        charges = payments.select { |p| p[:id].to_s == processor_id }
        charges.try(:first)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def paddle_refund!(amount_to_refund)
        return unless owner.subscription
        payments = PaddlePay::Subscription::Payment.list({subscription_id: owner.subscription.processor_id, is_paid: 1})
        if payments.count > 0
          PaddlePay::Subscription::Payment.refund(payments.last[:id], {amount: amount_to_refund})
          update(amount_refunded: amount_to_refund)
        else
          raise Error, "Payment not found"
        end
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end
    end
  end
end
