# A subscription's first authorized transaction is created, or a successful transaction moves a subscription from the Past Due status to the Active status. Subscriptions with trial periods will not trigger this notification when they move from the trial period into the first billing cycle.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionWentActive
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay::Subscription.find_by_processor_and_id(:braintree, subscription.id)
          return unless pay_subscription.present?

          pay_subscription.update!(status: :active)
        end
      end
    end
  end
end
