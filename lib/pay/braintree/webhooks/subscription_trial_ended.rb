# A subscription's trial period ends.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionTrialEnded
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay.subscription_model.find_by(processor: :braintree, processor_id: subscription.id)
          return unless pay_subscription.present?

          pay_subscription.update(trial_ends_at: Time.zone.now)
        end
      end
    end
  end
end
