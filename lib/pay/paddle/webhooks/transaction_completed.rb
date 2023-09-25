module Pay
  module Paddle
    module Webhooks
      class TransactionCompleted
        def call(event)
          Pay::Paddle::Charge.sync(event.id)
        end
      end
    end
  end
end
