# A subscription has moved from the Active status to the Past Due status. This will only be triggered when the initial transaction in a billing cycle is declined. Once the status moves to past due, it will not be triggered again in that billing cycle.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionWentPastDue
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          Pay::Braintree::Subscription.sync(subscription.id)
        end
      end
    end
  end
end
