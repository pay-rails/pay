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
            created_at: DateTime.parse(data["event_time"])
          }.merge(payment_params(data["subscription_id"]))

          charge.update(params)

          charge
        end

        def notify_user(billable, charge)
          if Pay.send_emails && charge.respond_to?(:receipt)
            Pay::UserMailer.with(billable: billable, charge: charge).receipt.deliver_later
          end
        end

        private

        def payment_params(subscription_id)
          subscription_user = PaddlePay::Subscription::User.list({subscription_id: subscription_id}).try(:first)
          payment_information = subscription_user ? subscription_user[:payment_information] : nil
          return {} if payment_information.nil?

          case payment_information[:payment_method]
          when "card"
            {
              card_type: payment_information[:card_type],
              card_last4: payment_information[:last_four_digits],
              card_exp_month: payment_information[:expiry_date].split("/").first,
              card_exp_year: payment_information[:expiry_date].split("/").last
            }
          when "paypal"
            {
              card_type: "PayPal"
            }
          else
            {}
          end
        end
      end
    end
  end
end
