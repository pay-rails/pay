module Pay
  module PaddleBilling
    module Webhooks
      class Subscription
        def call(event)
          Pay::PaddleBilling::Subscription.sync(event.id, object: event)
        end
      end
    end
  end
end
