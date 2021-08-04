module Pay
  module Stripe
    module Webhooks
      class CustomerDeleted
        def call(event)
          object = event.data.object
          pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.id)
          pay_customer&.destroy
        end
      end
    end
  end
end
