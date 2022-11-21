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
          Pay::Stripe::Charge.sync(object.latest_charge, stripe_account: event.try(:account))
        end
      end
    end
  end
end
