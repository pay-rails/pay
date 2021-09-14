module Pay
  module Paddle
    module Webhooks
      class SubscriptionCancelled
        def call(event)
          pay_subscription = Pay::Subscription.find_by_processor_and_id(:paddle, event.subscription_id)

          # We couldn't find the subscription for some reason, maybe it's from another service
          return if pay_subscription.nil?

          # User canceled subscriptions have an ends_at
          # Automatically canceled subscriptions need this value set
          pay_subscription.update!(ends_at: Time.zone.parse(event.cancellation_effective_date)) if pay_subscription.ends_at.blank? && event.cancellation_effective_date.present?

          # Paddle doesn't allow reusing customers, so we should remove their payment methods
          Pay::PaymentMethod.where(customer_id: pay_subscription.customer_id).destroy_all
        end
      end
    end
  end
end
