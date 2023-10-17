module Pay
  module Stripe
    module Webhooks
      class CustomerDeleted
        def call(event)
          object = event.data.object
          pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.id)

          # Skip processing if this customer is not in the database
          return unless pay_customer

          # Mark all subscriptions as canceled
          pay_customer.subscriptions.active.update_all(ends_at: Time.current, status: "canceled")

          # Remove all payment methods
          pay_customer.payment_methods.destroy_all

          # Mark customer as deleted
          pay_customer.update!(default: false, deleted_at: Time.current)
        end
      end
    end
  end
end
