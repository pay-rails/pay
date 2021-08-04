module Pay
  module Stripe
    module Webhooks
      class SubscriptionCreated
        def call(event)
          object = event.data.object
          Pay::Stripe::Subscription.sync(object.id, options: { stripe_account: event.account })
        end
      end
    end
  end
end
