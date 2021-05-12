module Pay
  module Stripe
    module Webhooks
      class AccountUpdated
        def call(event)
          object = event.data.object

          merchant = Pay.find_merchant(object.id)

          return unless merchant.present?

          merchant.update(onboarding_complete: object.charges_enabled)
        end
      end
    end
  end
end
