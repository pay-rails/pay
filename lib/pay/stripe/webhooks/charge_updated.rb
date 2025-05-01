module Pay
  module Stripe
    module Webhooks
      class ChargeUpdated
        def call(event)
          Pay::Stripe::Charge.sync(event.data.object.id, stripe_account: event.try(:account))
        end
      end
    end
  end
end
