module Pay
  module Lago
    module Webhooks
      class SubscriptionTerminated
        def call(event)
          subscription = event.subscription
          Pay::Lago::Subscription.sync(subscription.external_customer_id, subscription.external_id, object: subscription)
        end
      end
    end
  end
end
