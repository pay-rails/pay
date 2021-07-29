require "test_helper"

class Pay::Stripe::Webhooks::AccountUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/account_updated_event.json")
  end

  test "an account is authorized" do
    @account = Account.create!
    merchant = @account.pay_merchants.create processor: :stripe, processor_id: @event.data.data.object.id, default: true

    Pay::Stripe::Webhooks::AccountUpdated.new.call(@event.data)

    assert merchant.reload.onboarding_complete
  end
end
