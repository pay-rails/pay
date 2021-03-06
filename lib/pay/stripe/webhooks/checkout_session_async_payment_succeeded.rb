module Pay
  module Stripe
    module Webhooks
      class CheckoutSessionAsyncPaymentSucceeded
        def call(event)
          if event.data.object.subscription
            Pay::Stripe::Subscription.sync(event.data.object.subscription)
          end
        end
      end
    end
  end
end
