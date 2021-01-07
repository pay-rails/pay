module Pay
  module Stripe
    module Webhooks
      class ChargeRefunded
        def call(event)
          object = event.data.object
          charge = Pay.charge_model.find_by(processor: :stripe, processor_id: object.id)

          return unless charge.present?

          charge.update(amount_refunded: object.amount_refunded)
          notify_user(charge.owner, charge)
        end

        def notify_user(billable, charge)
          if Pay.send_emails
            Pay::UserMailer.with(billable: billable, charge: charge).refund.deliver_later
          end
        end
      end
    end
  end
end
