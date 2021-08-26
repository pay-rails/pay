module Pay
  module Stripe
    module Webhooks
      class PaymentMethodDetached
        def call(event)
          object = event.data.object
          Pay::PaymentMethod.find_by_processor_and_id(:stripe, object.id)&.destroy
        end
      end
    end
  end
end
