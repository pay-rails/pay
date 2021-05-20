require "test_helper"

class Pay::Stripe::Webhooks::ChargeRefundedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/charge_refunded_event.json")
  end

  test "a charge is updated with refunded amount" do
    Pay::Stripe::Charge.expects(:sync)
    Pay::Stripe::Webhooks::ChargeRefunded.new.call(@event)
  end
end
