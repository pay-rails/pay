module Pay
  module PaddleClassic
    class Charge < Pay::Charge
      store_accessor :data, :paddle_receipt_url

      def api_record
        return unless customer.subscription

        payments = PaddleClassic.client.payments.list(subscription_id: customer.subscription.processor_id)
        charges = payments.data.select { |p| p[:id].to_s == processor_id }
        charges.try(:first)
      rescue ::Paddle::Classic::Error => e
        raise Pay::PaddleClassic::Error, e
      end

      def refund!(amount_to_refund = nil)
        return unless customer.subscription
        amount_to_refund ||= amount

        payments = PaddleClassic.client.payments.list(subscription_id: customer.subscription.processor_id, is_paid: 1)
        raise Error, "Payment not found" unless payments.total > 0

        PaddleClassic.client.payments.refund(order_id: payments.data.last[:id], amount: amount_to_refund)
        update(amount_refunded: amount_to_refund)
      rescue ::Paddle::Classic::Error => e
        raise Pay::PaddleClassic::Error, e
      end
    end
  end
end
