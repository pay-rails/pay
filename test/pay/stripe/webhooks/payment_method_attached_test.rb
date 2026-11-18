require "test_helper"

class Pay::Stripe::Webhooks::PaymentMethodAttachedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("payment_method.attached")
  end

  test "payment_method.attached adds the payment method to the database" do
    ::Stripe::PaymentMethodService.any_instance.expects(:retrieve).returns(@event.data.object)
    ::Stripe::CustomerService.any_instance.expects(:retrieve).returns ::Stripe::Customer.construct_from(id: @event.data.object.customer, invoice_settings: {default_payment_method: nil})

    assert_difference "Pay::PaymentMethod.count", 1 do
      Pay::Stripe::Webhooks::PaymentMethodAttached.new.call(@event)
    end
  end
end
