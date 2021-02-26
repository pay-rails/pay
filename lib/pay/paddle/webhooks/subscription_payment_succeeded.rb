module Pay
  module Paddle
    module Webhooks
      class SubscriptionPaymentSucceeded
        def call(event)
          billable = Pay.find_billable(processor: :paddle, processor_id: event["user_id"])
          return unless billable.present?
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
            paddle_receipt_url: event["receipt_url"],
            created_at: Time.zone.parse(event["event_time"])
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
