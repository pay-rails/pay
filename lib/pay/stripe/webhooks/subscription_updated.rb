module Pay
  module Stripe
    module Webhooks
      class SubscriptionUpdated
        def call(event)
          object = event.data.object
          Pay::Stripe::Subscription.sync(object.id, options: { stripe_account: object.id })
        end
      end
    end
  end
end
