module Pay
  module Paddle
    module Webhooks
      class SubscriptionPaymentRefunded
        def call(event)
          pay_charge = Pay::Charge.find_by_processor_and_id(:paddle, event.subscription_payment_id)
          return unless pay_charge.present?

          pay_charge.update!(amount_refunded: (event.gross_refund.to_f * 100).to_i)

          if Pay.send_email?(:refund, pay_charge)
            Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).refund.deliver_later
          end
        end
      end
    end
  end
end
