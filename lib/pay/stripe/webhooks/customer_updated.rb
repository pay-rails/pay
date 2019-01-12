module Pay
  module Stripe
    module Webhooks

      class CustomerUpdated
        def call(event)
          object = event.data.object
          user = User.find_by(processor: :stripe, processor_id: object.id)

          # Couldn't find user, we can skip
          return unless user.present?

          user.update_card_from_stripe
        end
      end

    end
  end
end
