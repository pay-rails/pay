module Pay
  module Stripe
    module Webhooks
      class SubscriptionUpdated
        def call(event)
          object = event.data.object
          subscription = Pay.subscription_model.find_by(processor: :stripe, processor_id: object.id)

          return if subscription.nil?

          # Delete any subscription attempts that have expired
          if object.status == "incomplete_expired"
            subscription.destroy
            return
          end

          subscription.status = object.status
          subscription.quantity = object.quantity
          subscription.processor_plan = object.plan.id
          subscription.trial_ends_at = Time.at(object.trial_end) if object.trial_end.present?

          # If user was on trial, their subscription ends at the end of the trial
          subscription.ends_at = if object.cancel_at_period_end && subscription.on_trial?
            subscription.trial_ends_at

          # User wasn't on trial, so subscription ends at period end
          elsif object.cancel_at_period_end
            Time.at(object.current_period_end)

            # Subscription isn't marked to cancel at period end
          end

          subscription.save!
        end
      end
    end
  end
end
