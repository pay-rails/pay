module Pay
  module Stripe
    module Webhooks
      class PaymentMethodUpdated
        def call(event)
          object = event.data.object

          if object.customer
            pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)

            # Couldn't find user, we can skip
            return unless pay_customer.present?

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
