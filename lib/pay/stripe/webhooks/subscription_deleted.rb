module Pay
  module Stripe
    module Webhooks
      # Canceled subscriptions are still accessible via the API, so they sync the same way as an update
      class SubscriptionDeleted < SubscriptionUpdated
      end
    end
  end
end
