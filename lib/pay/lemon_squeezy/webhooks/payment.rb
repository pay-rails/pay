module Pay
  module LemonSqueezy
    module Webhooks
      class Payment
        def call(event)
          Pay::LemonSqueezy::Charge.sync(event.data.id)
        end
      end
    end
  end
end
