module Pay
  module Paddle
    module Webhooks
      class SubscriptionUpdated
        def call(event)
          subscription = Pay.subscription_model.find_by(processor: :paddle, processor_id: event["subscription_id"])

          return if subscription.nil?

          case event["status"]
          when "deleted"
            subscription.status = "canceled"
            subscription.ends_at = Time.zone.parse(event["next_bill_date"]) || Time.zone.now if subscription.ends_at.blank?
          when "trialing"
            subscription.status = "trialing"
            subscription.trial_ends_at = Time.zone.parse(event["next_bill_date"])
          when "active"
            subscription.status = "active"
            subscription.paddle_paused_from = Time.zone.parse(event["paused_from"]) if event["paused_from"].present?
          else
            subscription.status = event["status"]
          end

          subscription.quantity = event["new_quantity"]
          subscription.processor_plan = event["subscription_plan_id"]
          subscription.paddle_update_url = event["update_url"]
          subscription.paddle_cancel_url = event["cancel_url"]

          # If user was on trial, their subscription ends at the end of the trial
          subscription.ends_at = subscription.trial_ends_at if subscription.on_trial?

          subscription.save!
        end
      end
    end
  end
end
