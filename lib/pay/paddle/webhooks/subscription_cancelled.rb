module Pay
  module Paddle
    module Webhooks
      class SubscriptionCancelled
        def call(event)
          subscription = Pay.subscription_model.find_by(processor: :paddle, processor_id: event["subscription_id"])

          # We couldn't find the subscription for some reason, maybe it's from another service
          return if subscription.nil?

          # User canceled subscriptions have an ends_at
          # Automatically canceled subscriptions need this value set
          subscription.update!(ends_at: Time.zone.parse(event["cancellation_effective_date"])) if subscription.ends_at.blank? && event["cancellation_effective_date"].present?
        end
      end
    end
  end
end
