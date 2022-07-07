module Pay
  module Stripe
    module Webhooks
      class PaymentMethodAttached
        def call(event)
          object = event.data.object

          Pay::Stripe::PaymentMethod.sync(object.id, object: object)
        end
      end
    end
  end
end
