module Pay
  module Stripe
    module Webhooks
      class PaymentMethodUpdated
        def call(event)
          object = event.data.object
          billable = Pay.find_billable(processor: :stripe, processor_id: object.customer)

          # Couldn't find user, we can skip
          return unless billable.present?

          Pay::Stripe::Billable.new(billable).sync_card_from_stripe
        end
      end
    end
  end
end
