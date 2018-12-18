module Pay
  module Stripe
    class SubscriptionUpdated
      def call(event)
        object = event.data.object
        subscription = ::Subscription.find_by(processor: :stripe, processor_id: object.id)

        return if subscription.nil?

        subscription.quantity      = object.quantity
        subscription.processor_id  = object.plan.id
        subscription.trial_ends_at = Time.at(object.trial_end) if object.trial_end.present?

        # If user was on trial, their subscription ends at the end of the trial
        if object.cancel_at_period_end && subscription.on_trial?
          subscription.ends_at = subscription.trial_ends_at

        # User wasn't on trial, so subscription ends at period end
        elsif object.cancel_at_period_end
          subscription.ends_at = Time.at(object.current_period_end)

        # Subscription isn't marked to cancel at period end
        else
          subscription.ends_at = nil
        end

        subscription.save
      end
    end
  end
end

