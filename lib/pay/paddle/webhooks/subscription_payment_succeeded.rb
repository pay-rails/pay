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
          charge
        end

        def create_charge(user, data)
          charge = user.charges.find_or_initialize_by(
            processor: :paddle,
            processor_id: data["subscription_payment_id"]
          )

          charge.update(
            amount: Integer(data["sale_gross"].to_f * 100),
            card_type: data["payment_method"],
            receipt_url: data["receipt_url"],
            created_at: DateTime.parse(data["event_time"])
          )

          charge
        end

        def notify_user(user, charge)
          if Pay.send_emails && charge.respond_to?(:receipt)
            Pay::UserMailer.receipt(user, charge).deliver_later
          end
        end

      end
    end
  end
end