module Pay
  module Stripe
    module Webhooks
      class PaymentIntentSucceeded
        # This webhook does NOT send notifications because stripe sends both
        # `charge.succeeded` and `payment_intent.succeeded` events.
        #
        # We use `charge.succeeded` as the single place to send notifications

        def call(event)
          object = event.data.object
          object.charges.data.each do |charge|
            Pay::Stripe::Charge.sync(charge.id)
          end
        end
      end
    end
  end
end
