module Pay
  module Paddle
    module Webhooks
      class SubscriptionCreated

        def initialize(data)

          # We may already have the subscription in the database, so we can update that record
          subscription = Pay.subscription_model.find_by(processor: :paddle, processor_id: data["subscription_id"])

          # Create the subscription in the database if we don't have it already
          if subscription.nil?

            # The customer could already be in the database
            owner = Pay.find_billable(processor: :paddle, processor_id: data["user_id"])
            
            if owner.nil?
              owner = owner_by_passtrough(data["passthrough"], data["subscription_plan_id"])
              owner.update!(processor: "paddle", processor_id: data["user_id"]) if owner
            end

            if owner.nil?
              Rails.logger.error("[Pay] Unable to find Pay::Billable with owner: '#{data["passthrough"]}'. Searched these models: #{Pay.billable_models.join(", ")}")
              return
            end

            subscription = Pay.subscription_model.new(owner: owner, name: "default", processor: "paddle", processor_id: data["subscription_id"], status: :active)
          end

          subscription.quantity = data["quantity"]
          subscription.processor_plan = data["subscription_plan_id"]
          subscription.update_url = data["update_url"]
          subscription.cancel_url = data["cancel_url"]
          subscription.trial_ends_at = Time.zone.parse(data["next_bill_date"]) if data["status"] == "trialing"

          # If user was on trial, their subscription ends at the end of the trial
          subscription.ends_at = if ["paused", "deleted"].include?(data["status"]) && subscription.on_trial?
            subscription.trial_ends_at

          # User wasn't on trial, so subscription ends at period end
          elsif ["paused", "deleted"].include?(data["status"])
            Time.zone.parse(data["next_bill_date"])

            # Subscription isn't marked to cancel at period end
          end

          subscription.save!
        end

        private 

        def owner_by_passtrough(passthrough, product_id)
          passthrough_json = JSON.parse(passthrough)
          GlobalID::Locator.locate_signed(passthrough_json["owner_sgid"], for: "paddle_#{product_id}")
        rescue JSON::ParserError
          nil
        end

      end
    end
  end
end