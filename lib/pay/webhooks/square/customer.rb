module Pay
  module Square
    module Webhooks
      class Customer
        def call(event)
          object = event.data&.object&.customer
          return unless object&.id

          pay_customer = Pay::Customer.find_by(processor: :square, processor_id: object.id)
          return unless pay_customer

          if event.type.to_s == "customer.deleted"
            pay_customer.update(deleted_at: Time.current) if pay_customer.respond_to?(:deleted_at)
          end
        end
      end
    end
  end
end
