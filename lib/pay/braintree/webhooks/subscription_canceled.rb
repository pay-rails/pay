# A subscription is canceled.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionCanceled
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay::Subscription.find_by_processor_and_id(:braintree, subscription.id)
          return unless pay_subscription.present?

          ends_at = Time.current
          pay_subscription.update!(
            status: :canceled,
            trial_ends_at: (ends_at if pay_subscription.trial_ends_at?),
            ends_at: ends_at
          )
        end
      end
    end
  end
end
