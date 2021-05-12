module Pay
  module Stripe
    module Webhooks
      class AccountUpdated
        def call(event)
          object = event.data
          merchant_object = object.data.object

          merchant = Pay.find_merchant(:stripe, {stripe_connect_account_id: merchant_object.id})
          merchant.update(onboarding_complete: merchant_object.charges_enabled)
        end
      end
    end
  end
end
