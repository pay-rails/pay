module Pay
  module Paddle
    module Webhooks
      class TransactionUpdated
        def call(event)
          Pay::Paddle::Charge.sync(event.id)
        end
      end
    end
  end
end
