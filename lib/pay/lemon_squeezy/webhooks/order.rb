module Pay
  module LemonSqueezy
    module Webhooks
      class Order
        def call(order)
          Pay::LemonSqueezy.sync_order(order.id, object: order)
        end
      end
    end
  end
end
