module Pay
  module PaddleClassic
    class Charge
      attr_reader :pay_charge

      delegate :processor_id, :customer, to: :pay_charge

      def initialize(pay_charge)
        @pay_charge = pay_charge
      end

      def charge
        return unless customer.subscription

        payments = PaddleClassic.client.payments.list(subscription_id: customer.subscription.processor_id)
        charges = payments.data.select { |p| p[:id].to_s == processor_id }
        charges.try(:first)
      rescue ::Paddle::Classic::Error => e
        raise Pay::PaddleClassic::Error, e
      end

      def refund!(amount_to_refund)
        return unless customer.subscription

        payments = PaddleClassic.client.payments.list(subscription_id: customer.subscription.processor_id, is_paid: 1)
        raise Error, "Payment not found" unless payments.total > 0

        PaddleClassic.client.payments.refund(order_id: payments.data.last[:id], amount: amount_to_refund)
        pay_charge.update(amount_refunded: amount_to_refund)
      rescue ::Paddle::Classic::Error => e
        raise Pay::PaddleClassic::Error, e
      end
    end
  end
end
