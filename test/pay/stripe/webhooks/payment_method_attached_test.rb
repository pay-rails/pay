require "test_helper"

class Pay::Stripe::Webhooks::PaymentMethodAttachedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("payment_method.attached")
  end

  test "payment_method.detached removes payment method from database" do
    assert_difference "Pay::PaymentMethod.count", 1 do
      Pay::Stripe::Webhooks::PaymentMethodAttached.new.call(@event)
    end
  end
end
