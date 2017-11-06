module Pay
  module Stripe
    class ChargeRefunded
      def call(event)
        object = event.data.object
        charge = Charge.find_by(processor: :stripe, processor_id: object.id)

        return unless charge.present?

        charge.update(amount_refunded: object.amount_refunded)
        notify_user(charge)
      end

      def notify_user(charge)
        # Pay::UserMailer.refund(charge).deliver_later
      end
    end
  end
end
