module Pay
  module LemonSqueezy
    module Webhooks
      class SubscriptionCreated
        def call(event)
          Pay::LemonSqueezy::Subscription.sync(event.id, object: event)
        end
      end
    end
  end
end
