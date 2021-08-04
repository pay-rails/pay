module Pay
  module Stripe
    module Webhooks
      class AccountUpdated
        def call(event)
          object = event.data.object

          merchant = Pay::Merchant.find_by(processor: :stripe, processor_id: object.id)
          return unless merchant

          merchant.update(onboarding_complete: object.charges_enabled)
        end
      end
    end
  end
end
