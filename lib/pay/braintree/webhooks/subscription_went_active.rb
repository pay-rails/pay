# A subscription's first authorized transaction is created, or a successful transaction moves a subscription from the Past Due status to the Active status.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionWentActive < Subscription
      end
    end
  end
end
