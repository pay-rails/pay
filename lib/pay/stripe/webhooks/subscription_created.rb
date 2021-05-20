module Pay
  module Stripe
    module Webhooks
      class SubscriptionCreated
        def call(event)
          Pay::Stripe::Subscription.sync(event.data.object.id)
        end
      end
    end
  end
end
