module Pay
  module Paddle
    module Webhooks
      class SubscriptionPaymentRefunded
        def call(event)
          charge = Pay.charge_model.find_by(processor: :paddle, processor_id: event["subscription_payment_id"])
          return unless charge.present?

          charge.update(amount_refunded: Integer(event["gross_refund"].to_f * 100))
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
