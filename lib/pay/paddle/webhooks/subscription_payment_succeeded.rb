module Pay
  module Paddle
    module Webhooks
      class SubscriptionPaymentSucceeded
        def call(event)
          billable = Pay.find_billable(processor: :paddle, processor_id: event["user_id"])

          if billable.nil?
            billable = Pay::Paddle.owner_from_passthrough(event["passthrough"])
            billable&.update!(processor: "paddle", processor_id: event["user_id"])
          end

          if billable.nil?
            Rails.logger.error("[Pay] Unable to find Pay::Billable with owner: '#{event["passthrough"]}'. Searched these models: #{Pay.billable_models.join(", ")}")
            return
          end

          return if billable.charges.where(processor_id: event["subscription_payment_id"]).any?

          charge = create_charge(billable, event)
          notify_user(billable, charge)
        end

        def create_charge(user, event)
          charge = user.charges.find_or_initialize_by(
            processor: :paddle,
            processor_id: event["subscription_payment_id"]
          )

          params = {
            amount: Integer(event["sale_gross"].to_f * 100),
            card_type: event["payment_method"],
            created_at: Time.zone.parse(event["event_time"]),
            currency: event["currency"],
            paddle_receipt_url: event["receipt_url"],
            subscription: Pay::Subscription.find_by(processor: :paddle, processor_id: event["subscription_id"])
          }

          payment_information = Pay::Paddle::Billable.new(user).payment_information(event["subscription_id"])

          charge.update(params.merge(payment_information))
          user.update(payment_information)

          charge
        end

        def notify_user(billable, charge)
          if Pay.send_emails && charge.respond_to?(:receipt)
            Pay::UserMailer.with(billable: billable, charge: charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
