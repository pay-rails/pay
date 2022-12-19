# A subscription is canceled.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionCanceled
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          Pay::Braintree::Subscription.sync(subscription.id)
        end
      end
    end
  end
end
