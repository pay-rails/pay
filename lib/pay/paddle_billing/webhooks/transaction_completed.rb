module Pay
  module PaddleBilling
    module Webhooks
      class TransactionCompleted
        def call(event)
          Pay::PaddleBilling::Charge.sync(event.id)
        end
      end
    end
  end
end
