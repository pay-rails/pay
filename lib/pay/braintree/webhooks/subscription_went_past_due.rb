# A subscription has moved from the Active status to the Past Due status. This will only be triggered when the initial transaction in a billing cycle is declined. Once the status moves to past due, it will not be triggered again in that billing cycle.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionWentPastDue
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay.subscription_model.find_by(processor: :braintree, processor_id: subscription.id)
          return unless pay_subscription.present?

          pay_subscription.update!(status: :past_due)
        end
      end
    end
  end
end
