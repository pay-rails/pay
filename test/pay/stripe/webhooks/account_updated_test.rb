require "test_helper"

class Pay::Stripe::Webhooks::AccountUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("account.updated")
  end

  test "an account is authorized" do
    account = Account.create!
    account.set_merchant_processor :stripe
    account.merchant.update processor_id: @event.data.data.object.id

    Pay::Stripe::Webhooks::AccountUpdated.new.call(@event.data)

    assert account.merchant.reload.onboarding_complete
  end
end
