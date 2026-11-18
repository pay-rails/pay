module Pay
  module Stripe
    module Webhooks
      class ChargeUpdated
        def call(event)
          Pay::Stripe::Charge.sync(event.data.object.id, stripe_account: event.try(:account), customer: Pay::Stripe.find_pay_customer(event.data.object.customer))
        end
      end
    end
  end
end
