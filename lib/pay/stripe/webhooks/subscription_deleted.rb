module Pay
  module Stripe
    module Webhooks
      class SubscriptionDeleted
        def call(event)
          object = event.data.object
          subscription = Pay.subscription_model.find_by(processor: :stripe, processor_id: object.id)

          # We couldn't find the subscription for some reason, maybe it's from another service
          return if subscription.nil?

          # User canceled subscriptions have an ends_at
          # Automatically canceled subscriptions need this value set
          subscription.update!(ends_at: Time.at(object.ended_at)) if subscription.ends_at.blank? && object.ended_at.present?
        end
      end
    end
  end
end
