module Pay
  module Stripe
    module Webhooks
      # If a subscription is manually created on Stripe, we want to sync it the same way as an update
      class SubscriptionCreated < SubscriptionUpdated
      end
    end
  end
end
