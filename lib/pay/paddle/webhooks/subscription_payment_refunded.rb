module Pay
  module Paddle
    module Webhooks
      class SubscriptionPaymentRefunded
        def call(event)
          charge = Pay::Charge.find_by_processor_and_id(:paddle, event["subscription_payment_id"])
          return unless charge.present?

          charge.update(amount_refunded: (event["gross_refund"].to_f * 100).to_i)
          notify_user(charge.customer.owner, charge)
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
