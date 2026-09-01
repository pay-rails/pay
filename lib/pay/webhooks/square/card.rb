module Pay
  module Square
    module Webhooks
      class Card
        def call(event)
          object = event.data&.object&.card
          return unless object&.id

          pay_customer = object.customer_id.present? ? Pay::Customer.find_by(processor: :square, processor_id: object.customer_id) : nil
          return unless pay_customer

          if event.type.to_s == "card.disabled"
            Pay::PaymentMethod.find_by_processor_and_id(:square, object.id)&.destroy
          else
            Pay::Square::PaymentMethod.sync(object.id, pay_customer: pay_customer)
          end
        end
      end
    end
  end
end
