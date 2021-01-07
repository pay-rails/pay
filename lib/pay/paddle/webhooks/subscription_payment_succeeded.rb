module Pay
  module Paddle
    module Webhooks
      class SubscriptionPaymentSucceeded
        def initialize(data)
          billable = Pay.find_billable(processor: :paddle, processor_id: data["user_id"])
          return unless billable.present?
          return if billable.charges.where(processor_id: data["subscription_payment_id"]).any?

          charge = create_charge(billable, data)
          notify_user(billable, charge)
        end

        def create_charge(user, data)
          charge = user.charges.find_or_initialize_by(
            processor: :paddle,
            processor_id: data["subscription_payment_id"]
          )

          params = {
            amount: Integer(data["sale_gross"].to_f * 100),
            card_type: data["payment_method"],
            paddle_receipt_url: data["receipt_url"],
            created_at: Time.zone.parse(data["event_time"])
          }

          payment_information = user.paddle_payment_information(data["subscription_id"])

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
