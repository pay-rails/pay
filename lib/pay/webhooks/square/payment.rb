module Pay
  module Square
    module Webhooks
      class Payment
        def call(event)
          object = event.data&.object&.payment
          return unless object&.id

          pay_customer = object.customer_id.present? ? Pay::Customer.find_by(processor: :square, processor_id: object.customer_id) : nil
          return unless pay_customer

          pay_charge = Pay::Square::Charge.sync(object.id, pay_customer: pay_customer)

          if pay_charge && Pay.send_email?(:receipt, pay_charge)
            Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
