# A subscription reaches the specified number of billing cycles and expires.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionExpired
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          Pay::Braintree::Subscription.sync(subscription.id)
        end
      end
    end
  end
end
