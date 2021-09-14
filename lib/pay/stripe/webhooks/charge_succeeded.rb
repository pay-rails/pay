module Pay
  module Stripe
    module Webhooks
      class ChargeSucceeded
        def call(event)
          pay_charge = Pay::Stripe::Charge.sync(event.data.object.id, stripe_account: event.try(:account))

          if pay_charge && Pay.send_emails
            Pay::UserMailer.with(pay_customer: pay_charge.customer, charge: pay_charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
