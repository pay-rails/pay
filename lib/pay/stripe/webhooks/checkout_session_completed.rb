module Pay
  module Stripe
    module Webhooks
      class CheckoutSessionCompleted
        def call(event)
          # TODO: Also handle payment intents

          if event.data.object.subscription
            Pay::Stripe::Subscription.sync(event.data.object.subscription, stripe_account: event.try(:account))
          end
        end
      end
    end
  end
end
