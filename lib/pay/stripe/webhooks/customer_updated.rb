module Pay
  module Stripe
    module Webhooks
      class CustomerUpdated
        def call(event)
          object = event.data.object
          billable = Pay.find_billable(processor: :stripe, processor_id: object.id)

          # Couldn't find user, we can skip
          return unless billable.present?

          Pay::Stripe::Billable.new(billable).sync_card_from_stripe
        end
      end
    end
  end
end
