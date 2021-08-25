# A subscription's trial period ends.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionTrialEnded
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay::Subscription.find_by_processor_and_id(:braintree, subscription.id)
          return unless pay_subscription.present?

          pay_subscription.update(trial_ends_at: Time.current)
        end
      end
    end
  end
end
