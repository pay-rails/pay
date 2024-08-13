module Pay
  module LemonSqueezy
    module Webhooks
      class SubscriptionPayment
        def call(event)
          Pay::LemonSqueezy::Charge.sync_subscription_invoice(event.data.id)
        end
      end
    end
  end
end
