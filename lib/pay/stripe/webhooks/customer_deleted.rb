module Pay
  module Stripe
    module Webhooks
      class CustomerDeleted
        def call(event)
          object = event.data.object
          user = Pay.user_model.find_by(processor: :stripe, processor_id: object.id)

          # Couldn't find user, we can skip
          return unless user.present?

          user.update(
            processor_id: nil,
            trial_ends_at: nil,
            card_type: nil,
            card_last4: nil,
            card_exp_month: nil,
            card_exp_year: nil,
          )

          user.subscriptions.update_all(
            trial_ends_at: nil,
            ends_at: Time.zone.now,
          )
        end
      end
    end
  end
end
