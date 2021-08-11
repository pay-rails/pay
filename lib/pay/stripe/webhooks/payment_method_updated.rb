module Pay
  module Stripe
    module Webhooks
      class PaymentMethodUpdated
        def call(event)
          object = event.data.object

          if object.customer
            billable = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)

            # Couldn't find user, we can skip
            return unless billable.present?

            Pay::Stripe::Billable.new(billable).sync_payment_method_from_stripe

          else
            # If customer was removed, we should delete the payment method if it exists
            Pay::PaymentMethod.find_by_processor_and_id(:stripe, object.id)&.destroy
          end
        end
      end
    end
  end
end
