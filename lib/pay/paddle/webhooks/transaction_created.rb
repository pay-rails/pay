module Pay
  module Paddle
    module Webhooks
      class TransactionCreated
        def call(event)
          Pay::Paddle::Charge.sync(event.id)

          # if pay_charge && Pay.send_email?(:receipt, pay_charge)
          #   Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).receipt.deliver_later
          # end
        end
      end
    end
  end
end
