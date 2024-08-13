module Pay
  module LemonSqueezy
    module Webhooks
      class Subscription
        def call(subscription)
          Pay::LemonSqueezy::Subscription.sync(subscription.id, object: subscription)
        end
      end
    end
  end
end
