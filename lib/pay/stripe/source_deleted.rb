module Pay
  module Stripe
    class SourceDeleted
      def call(event)
        object = event.data.object
        user = User.find_by(processor: :stripe, processor_id: object.customer)

        # Couldn't find user, we can skip
        return unless user.present?

        user.update_card_from_stripe
      end
    end
  end
end

