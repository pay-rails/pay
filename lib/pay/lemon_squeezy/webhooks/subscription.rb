module Pay
  module LemonSqueezy
    module Webhooks
      class Subscription
        def call(event)
          Pay::LemonSqueezy::Subscription.sync(event.data.id, object: event)
        end
      end
    end
  end
end
