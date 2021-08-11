require "test_helper"

class Pay::Stripe::Webhooks::PaymentMethodDetachedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/payment_method.detached.json")
  end

  test "payment_method.detached removes payment method from database" do
    assert_difference "Pay::PaymentMethod.count", -1 do
      Pay::Stripe::Webhooks::PaymentMethodUpdated.new.call(@event)
    end
  end
end
