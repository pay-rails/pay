module Pay
  module Stripe
    module Webhooks
      class SubscriptionCreated
        def call(event)
          object = event.data.object

          # We may already have the subscription in the database, so we can update that record
          subscription = Pay.subscription_model.find_by(processor: :stripe, processor_id: object.id)

          # Create the subscription in the database if we don't have it already
          if subscription.nil?
            # The customer should already be in the database
            owner = Pay.find_billable(processor: :stripe, processor_id: object.customer)

            if owner.nil?
              Rails.logger.error("[Pay] Unable to find Pay::Billable with processor: :stripe and processor_id: '#{object.customer}'. Searched these models: #{Pay.billable_models.join(", ")}")
              return
            end

            subscription = Pay.subscription_model.new(name: Pay.default_product_name, owner: owner, processor: :stripe, processor_id: object.id)
          end

          subscription.quantity = object.quantity
          subscription.status = object.status
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
