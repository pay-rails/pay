require "test_helper"

class Pay::Stripe::Webhooks::PaymentMethodAttachedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("payment_method.attached")
  end

  test "payment_method.attached creates payment method in database" do
    fake_customer = OpenStruct.new(invoice_settings: OpenStruct.new(default_payment_method: nil))
    ::Stripe::Customer.expects(:retrieve).returns(fake_customer)

    assert_difference "Pay::PaymentMethod.count", 1 do
      Pay::Stripe::Webhooks::PaymentMethodAttached.new.call(@event)
    end
  end
end
