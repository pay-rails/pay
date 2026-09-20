# A subscription already exists and fails to create a successful charge.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionWentPastDue < Subscription
      end
    end
  end
end
