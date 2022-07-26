module Pay
  module Stripe
    module Webhooks
      class CheckoutSessionCompleted
        def call(event)
          # TODO: Also handle payment intents

          locate_owner(event.data.object)

          if (payment_intent_id = event.data.object.payment_intent)
            payment_intent = ::Stripe::PaymentIntent.retrieve(payment_intent_id, {stripe_account: event.try(:account)}.compact)
            payment_intent.charges.each do |charge|
              Pay::Stripe::Charge.sync(charge.id, stripe_account: event.try(:account))
            end
          end

          if (subscription_id = event.data.object.subscription)
            Pay::Stripe::Subscription.sync(subscription_id, stripe_account: event.try(:account))
          end
        end

        def locate_owner(object)
          return if object.client_reference_id.nil?

          # If there is a client reference ID, make sure we have a Pay::Customer record
          owner = client_id.start_with?("gid://") ? GlobalID::Locator.locate(client_id) : GlobalID::Locator.locate_signed(client_id)
          owner.add_payment_processor(:stripe, processor_id: object.customer)
        rescue
        end
      end
    end
  end
end
