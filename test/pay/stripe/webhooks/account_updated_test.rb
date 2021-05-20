require "test_helper"

class Pay::Stripe::Webhooks::AccountUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/account_updated_event.json")
  end

  test "an account is authorized" do
    @account = Account.create! merchant_processor: :stripe, stripe_connect_account_id: @event.data.data.object.id

    Pay::Stripe::Webhooks::AccountUpdated.new.call(@event.data)

    assert @account.reload.onboarding_complete
  end
end
