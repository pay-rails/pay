module Pay
  module Paddle
    module Webhooks
      class Subscription
        def call(event)
          Pay::Paddle::Subscription.sync(event.id, object: event)
        end
      end
    end
  end
end
