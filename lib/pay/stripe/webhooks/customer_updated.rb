module Pay
  module Stripe
    module Webhooks
      class CustomerUpdated
        def call(event)
          object = event.data.object
          user = Pay.user_model.find_by(processor: :stripe, processor_id: object.id)

          # Couldn't find user, we can skip
          return unless user.present?

          user.sync_card_from_stripe
        end
      end
    end
  end
end
