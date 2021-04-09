module Pay
  module Paddle
    module Webhooks
      class SubscriptionCreated
        def call(event)
          # We may already have the subscription in the database, so we can update that record
          subscription = Pay.subscription_model.find_by(processor: :paddle, processor_id: event["subscription_id"])

          # Create the subscription in the database if we don't have it already
          if subscription.nil?

            # The customer could already be in the database
            owner = Pay.find_billable(processor: :paddle, processor_id: event["user_id"])

            if owner.nil?
              owner = Pay::Paddle.owner_from_passthrough(event["passthrough"])
              owner&.update!(processor: "paddle", processor_id: event["user_id"])
            end

            if owner.nil?
              Rails.logger.error("[Pay] Unable to find Pay::Billable with owner: '#{event["passthrough"]}'. Searched these models: #{Pay.billable_models.join(", ")}")
              return
            end

            subscription = Pay.subscription_model.new(owner: owner, name: Pay.default_product_name, processor: "paddle", processor_id: event["subscription_id"], status: :active)
          end

          subscription.quantity = event["quantity"]
          subscription.processor_plan = event["subscription_plan_id"]
          subscription.paddle_update_url = event["update_url"]
          subscription.paddle_cancel_url = event["cancel_url"]
          subscription.trial_ends_at = Time.zone.parse(event["next_bill_date"]) if event["status"] == "trialing"

          # If user was on trial, their subscription ends at the end of the trial
          subscription.ends_at = if ["paused", "deleted"].include?(event["status"]) && subscription.on_trial?
            subscription.trial_ends_at

          # User wasn't on trial, so subscription ends at period end
          elsif ["paused", "deleted"].include?(event["status"])
            Time.zone.parse(event["next_bill_date"])

            # Subscription isn't marked to cancel at period end
          end

          subscription.save!
        end
      end
    end
  end
end
