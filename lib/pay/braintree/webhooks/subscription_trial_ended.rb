# A subscription's trial period ends.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionTrialEnded
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          Pay::Braintree::Subscription.sync(subscription.id)
        end
      end
    end
  end
end
