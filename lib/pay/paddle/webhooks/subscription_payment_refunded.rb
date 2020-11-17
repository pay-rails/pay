module Pay
  module Paddle
    module Webhooks
      class SubscriptionPaymentRefunded
        def initialize(data)
          charge = Pay.charge_model.find_by(processor: :paddle, processor_id: data["subscription_payment_id"])
          return unless charge.present?

          charge.update(amount_refunded: Integer(data["gross_refund"].to_f * 100))
          notify_user(charge.owner, charge)
        end

        def notify_user(user, charge)
          if Pay.send_emails
            Pay::UserMailer.refund(user, charge).deliver_later
          end
        end
      end
    end
  end
end
