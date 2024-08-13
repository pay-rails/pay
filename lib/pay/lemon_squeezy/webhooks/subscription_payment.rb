module Pay
  module LemonSqueezy
    module Webhooks
      class SubscriptionPayment
        def call(subscription_invoice)
          Pay::LemonSqueezy::Charge.sync_subscription_invoice(subscription_invoice.id, object: subscription_invoice)
        end
      end
    end
  end
end
