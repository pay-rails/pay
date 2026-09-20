module Pay
  module Braintree
    module Webhooks
      # Every Braintree subscription event is handled the same way: sync the subscription
      class Subscription
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          Pay::Braintree::Subscription.sync(subscription.id)
        end
      end
    end
  end
end
