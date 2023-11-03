require "test_helper"

class Pay::Stripe::PaymentMethodTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:stripe)
  end

  test "Stripe sync returns Pay::PaymentMethod" do
    ::Stripe::Customer.stubs(:retrieve).returns(::Stripe::Customer.construct_from(invoice_settings: {default_payment_method: nil}))
    pay_payment_method = Pay::Stripe::PaymentMethod.sync("pm_123", object: fake_stripe_payment_method)
    assert pay_payment_method.is_a?(Pay::PaymentMethod)
    refute pay_payment_method.default?
  end

  test "Stripe sync sets default if payment method is default in invoice settings" do
    ::Stripe::Customer.stubs(:retrieve).returns(::Stripe::Customer.construct_from(invoice_settings: {default_payment_method: "pm_123"}))
    pay_payment_method = Pay::Stripe::PaymentMethod.sync("pm_123", object: fake_stripe_payment_method)
    assert pay_payment_method.default?
  end

  test "Stripe sync skips PaymentMethod without customer" do
    @pay_customer.update!(processor_id: nil)
    pay_payment_method = Pay::Stripe::PaymentMethod.sync("pm_123", object: fake_stripe_payment_method(customer: nil))
    assert_nil pay_payment_method
  end

  test "Stripe sync Link payment method" do
    object = ::Stripe::PaymentMethod.construct_from json_fixture("stripe/payment_methods/link")
    attributes = Pay::Stripe::PaymentMethod.extract_attributes(object)
    assert_equal "link", attributes[:payment_method_type]
    assert_equal "customer@example.org", attributes[:email]
  end
end
