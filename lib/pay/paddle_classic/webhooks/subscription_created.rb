module Pay
  module PaddleClassic
    module Webhooks
      class SubscriptionCreated
        def call(event)
          Pay::PaddleClassic::Subscription.sync(event.subscription_id, object: event)
        end
      end
    end
  end
end
