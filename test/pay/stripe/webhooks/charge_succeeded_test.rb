require "test_helper"

class Pay::Stripe::Webhooks::ChargeSucceededTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/charge_succeeded_event.json")
  end

  test "a charge is created" do
    Pay::Stripe::Charge.expects(:sync)
    Pay::Stripe::Webhooks::ChargeSucceeded.new.call(@event)
  end
end
