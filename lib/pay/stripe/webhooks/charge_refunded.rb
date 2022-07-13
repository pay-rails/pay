module Pay
  module Stripe
    module Webhooks
      class ChargeRefunded
        def call(event)
          pay_charge = Pay::Stripe::Charge.sync(event.data.object.id, stripe_account: event.try(:account))

          if pay_charge && Pay.send_email?(:refund, pay_charge)
            Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).refund.deliver_later
          end
        end
      end
    end
  end
end
