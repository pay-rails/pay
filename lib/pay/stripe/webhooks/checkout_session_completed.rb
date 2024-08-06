module Pay
  module Stripe
    module Webhooks
      class CheckoutSessionCompleted
        def call(event)
          locate_owner(event.data.object)

          # By the time CheckoutSessionCompleted is fired, we probably missed the original events
          # Instead, we can sync the payment intent or subscription during this event to ensure they're in the database

          if (payment_intent_id = event.data.object.payment_intent)
            payment_intent = ::Stripe::PaymentIntent.retrieve({id: payment_intent_id}, {stripe_account: event.try(:account)}.compact)
            Pay::Stripe::Charge.sync(payment_intent.latest_charge, stripe_account: event.try(:account)) if payment_intent.latest_charge
          end

          if (subscription_id = event.data.object.subscription)
            Pay::Stripe::Subscription.sync(subscription_id, stripe_account: event.try(:account))
          end
        end

        def locate_owner(object)
          return if object.client_reference_id.nil?

          owner = Pay::Stripe.find_by_client_reference_id(object.client_reference_id)
          owner&.add_payment_processor(:stripe, processor_id: object.customer)
        end
      end
    end
  end
end
