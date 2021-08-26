module Pay
  module Stripe
    module Webhooks
      class SubscriptionCreated
        def call(event)
          Pay::Stripe::Subscription.sync(event.data.object.id, stripe_account: event.try(:account))
        end
      end
    end
  end
end
