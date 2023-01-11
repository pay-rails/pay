module Pay
  module Paddle
    module Webhooks
      class SubscriptionUpdated
        def call(event)
          pay_subscription = Pay::Subscription.find_by_processor_and_id(:paddle, event["subscription_id"])

          return if pay_subscription.nil?

          case event["status"]
          when "deleted"
            pay_subscription.status = "canceled"
            pay_subscription.ends_at = Time.zone.parse(event["next_bill_date"]) || Time.current if pay_subscription.ends_at.blank?
          when "trialing"
            pay_subscription.status = "trialing"
            pay_subscription.trial_ends_at = Time.zone.parse(event["next_bill_date"])
          when "active"
            pay_subscription.status = "active"
            pay_subscription.pause_starts_at = Time.zone.parse(event["paused_from"]) if event["paused_from"].present?
          else
            pay_subscription.status = event["status"]
          end

          pay_subscription.quantity = event["new_quantity"]
          pay_subscription.processor_plan = event["subscription_plan_id"]
          pay_subscription.paddle_update_url = event["update_url"]
          pay_subscription.paddle_cancel_url = event["cancel_url"]

          # If user was on trial, their subscription ends at the end of the trial
          pay_subscription.ends_at = pay_subscription.trial_ends_at if pay_subscription.on_trial?

          pay_subscription.save!
        end
      end
    end
  end
end
