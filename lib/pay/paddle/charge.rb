module Pay
  module Paddle
    class Charge
      attr_reader :pay_charge

      delegate :processor_id, :customer, to: :pay_charge

      def initialize(pay_charge)
        @pay_charge = pay_charge
      end

      def charge
        return unless customer.subscription
        payments = PaddlePay::Subscription::Payment.list({subscription_id: customer.subscription.processor_id})
        charges = payments.select { |p| p[:id].to_s == processor_id }
        charges.try(:first)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def refund!(amount_to_refund)
        return unless customer.subscription
        payments = PaddlePay::Subscription::Payment.list({subscription_id: customer.subscription.processor_id, is_paid: 1})
        if payments.count > 0
          PaddlePay::Subscription::Payment.refund(payments.last[:id], {amount: amount_to_refund})
          pay_charge.update(amount_refunded: amount_to_refund)
        else
          raise Error, "Payment not found"
        end
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end
    end
  end
end
