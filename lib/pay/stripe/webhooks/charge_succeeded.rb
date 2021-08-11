module Pay
  module Stripe
    module Webhooks
      class ChargeSucceeded
        def call(event)
          pay_charge = Pay::Stripe::Charge.sync(event.data.object.id, stripe_account: event.try(:account))
          notify_user(pay_charge.owner, pay_charge) if pay_charge
        end

        def notify_user(billable, charge)
          if Pay.send_emails && charge.respond_to?(:receipt)
            Pay::UserMailer.with(billable: billable, charge: charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
