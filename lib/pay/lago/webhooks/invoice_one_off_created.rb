module Pay
  module Lago
    module Webhooks
      class InvoiceOneOffCreated
        def call(event)
          pay_charge = Pay::Lago::Charge.sync(event.invoice.lago_id, object: event.invoice)

          if pay_charge && Pay.send_email?(:receipt, pay_charge)
            Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
