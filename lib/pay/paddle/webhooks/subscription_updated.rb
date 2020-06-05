module Pay
  module Paddle
    module Webhooks
      class SubscriptionUpdated

        def initialize(data)
          subscription = Pay.subscription_model.find_by(processor: :paddle, processor_id: data["subscription_id"])

          return if subscription.nil?

          subscription.status = data["status"] == "deleted" ? "canceled" : data["status"]
          subscription.quantity = data["new_quantity"]
          subscription.processor_plan = data["subscription_plan_id"]
          subscription.update_url = data["update_url"]
          subscription.cancel_url = data["cancel_url"]

          subscription.trial_ends_at = DateTime.parse(data["next_bill_date"]) if data["status"] == "trialing"

          # If user was on trial, their subscription ends at the end of the trial
          subscription.ends_at = if ["paused", "deleted"].include?(data["status"]) && subscription.on_trial?
            subscription.trial_ends_at

          # User wasn't on trial, so subscription ends at period end
          elsif ["paused", "deleted"].include?(data["status"])
            DateTime.parse(data["next_bill_date"])

            # Subscription isn't marked to cancel at period end
          end

          subscription.save!
        end

      end
    end
  end
end