module Pay
  module Stripe
    module Webhooks
      class SubscriptionDeleted
        def call(event)
          Pay::Stripe::Subscription.sync(event.data.object.id)
        end
      end
    end
  end
end
