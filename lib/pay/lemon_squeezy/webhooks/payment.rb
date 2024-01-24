module Pay
  module LemonSqueezy
    module Webhooks
      class Payment
        def call(event)
          Pay::LemonSqueezy::Charge.sync(event.id)
        end
      end
    end
  end
end
