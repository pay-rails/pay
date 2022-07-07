module Pay
  module Stripe
    module Webhooks
      class PaymentMethodUpdated
        def call(event)
          object = event.data.object

          if object.customer
            Pay::Stripe::PaymentMethod.sync(object.id, stripe_account: event.try(:account))
          else
            # If customer was removed, we should delete the payment method if it exists
            Pay::PaymentMethod.find_by_processor_and_id(:stripe, object.id)&.destroy
          end
        end
      end
    end
  end
end
