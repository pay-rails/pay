module Pay
  module Stripe
    module Webhooks
      class CustomerDeleted
        def call(event)
          object = event.data.object
          billable = Pay.find_billable(processor: :stripe, processor_id: object.id)

          # Couldn't find user, we can skip
          return unless billable.present?

          billable.update(
            processor_id: nil,
            trial_ends_at: nil,
            card_type: nil,
            card_last4: nil,
            card_exp_month: nil,
            card_exp_year: nil
          )

          billable.subscriptions.update_all(
            trial_ends_at: nil,
            ends_at: Time.zone.now
          )
        end
      end
    end
  end
end
