require "test_helper"

class Pay::Stripe::Webhooks::PaymentMethodUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("payment_method.updated")
  end

  test "updates payment method in database" do
    payment_method = pay_payment_methods(:one)

    # Spoof Stripe PaymentMethod lookup
    fake_payment_method = ::Stripe::PaymentMethod.construct_from(id: payment_method.processor_id, customer: "cus_1234", type: "card", card: ActiveSupport::InheritableOptions.new(brand: "Visa", last4: "4242", exp_month: "01", exp_year: "2034"))
    ::Stripe::PaymentMethod.expects(:retrieve).returns(fake_payment_method)

    fake_customer = ::Stripe::Customer.construct_from(invoice_settings: ActiveSupport::InheritableOptions.new(default_payment_method: nil))
    ::Stripe::Customer.expects(:retrieve).returns(fake_customer)

    assert_equal payment_method.exp_year, payment_method.exp_year
    Pay::Stripe::Webhooks::PaymentMethodUpdated.new.call(@event)

    payment_method.reload
    assert_equal "2034", payment_method.exp_year
  end
end
