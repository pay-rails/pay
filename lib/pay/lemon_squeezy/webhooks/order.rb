module Pay
  module LemonSqueezy
    module Webhooks
      class Order
        def call(event)
          Pay::LemonSqueezy.sync(event.data.id)
        end
      end
    end
  end
end
