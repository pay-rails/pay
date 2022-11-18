require "test_helper"

class Pay::Stripe::Webhooks::PaymentMethodAttachedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("payment_method.attached")
  end

  test "payment_method.attached removes payment method from database" do
    ::Stripe::PaymentMethod.expects(:retrieve).returns(@event.data.object)
    ::Stripe::Customer.expects(:retrieve).returns ::Stripe::Customer.construct_from(id: @event.data.object.customer, invoice_settings: {default_payment_method: nil})

    assert_difference "Pay::PaymentMethod.count", 1 do
      Pay::Stripe::Webhooks::PaymentMethodAttached.new.call(@event)
    end
  end
end
