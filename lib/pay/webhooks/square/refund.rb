module Pay
  module Square
    module Webhooks
      class Refund
        def call(event)
          object = event.data&.object&.refund
          return unless object&.payment_id

          pay_charge = Pay::Charge.find_by(processor_id: object.payment_id)
          pay_customer = pay_charge&.customer || ((object.respond_to?(:customer_id) && object.customer_id.present?) ? Pay::Customer.find_by(processor: :square, processor_id: object.customer_id) : nil)
          return unless pay_customer

          pay_charge = Pay::Square::Charge.sync(object.payment_id, pay_customer: pay_customer)

          if pay_charge && Pay.send_email?(:refund, pay_charge)
            Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).refund.deliver_later
          end
        end
      end
    end
  end
end
