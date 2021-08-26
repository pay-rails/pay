module Pay
  module Paddle
    module Webhooks
      class SubscriptionCreated
        def call(event)
          Pay::Paddle::Subscription.sync(event.subscription_id, object: event)
        end
      end
    end
  end
end
