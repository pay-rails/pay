module Pay
  module Stripe
    module Webhooks
      class ChargeRefunded
        def call(event)
          pay_charge = Pay::Stripe::Charge.sync(event.data.object.id)
          notify_user(pay_charge.owner, pay_charge) if pay_charge
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
