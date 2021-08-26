module Pay
  module Stripe
    module Webhooks
      class SubscriptionDeleted
        def call(event)
          # Canceled subscriptions are still accessible via the API, so we can sync their details
          Pay::Stripe::Subscription.sync(event.data.object.id, stripe_account: event.try(:account))
        end
      end
    end
  end
end
