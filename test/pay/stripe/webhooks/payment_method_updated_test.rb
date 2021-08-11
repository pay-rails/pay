require "test_helper"

class Pay::Stripe::Webhooks::PaymentMethodUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/payment_method.updated.json")
  end

  test "updates payment method in database" do
    assert_equal "2021", pay_payment_methods(:one).last4
    Pay::Stripe::Webhooks::PaymentMethodUpdated.new.call(@event)
    assert_equal "2034", pay_payment_methods(:one).last4
  end
end
