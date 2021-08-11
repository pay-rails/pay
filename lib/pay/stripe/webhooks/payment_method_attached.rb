module Pay
  module Stripe
    module Webhooks
      class PaymentMethodAttached
        def call(event)
          object = event.data.object
          pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)
          return unless pay_customer

          pay_customer.save_payment_method(object, default: false)
        end
      end
    end
  end
end

