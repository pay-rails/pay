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

  test "make_default! updates Stripe and syncs database" do
    # Create a default payment method
    pm1 = @pay_customer.payment_methods.create!(
      processor_id: "pm_default",
      payment_method_type: "card",
      default: true
    )

    # Create a second payment method
    pm2 = @pay_customer.payment_methods.create!(
      processor_id: "pm_new",
      payment_method_type: "card",
      default: false
    )

    # Mock Stripe API call
    ::Stripe::Customer.expects(:update).with(
      @pay_customer.processor_id,
      {invoice_settings: {default_payment_method: "pm_new"}},
      {}
    ).returns(true)

    # Make pm2 the default
    pm2.make_default!

    # Verify database state
    pm1.reload
    pm2.reload
    refute pm1.default?, "Old default should no longer be default"
    assert pm2.default?, "New payment method should be default"
  end

  test "make_default! returns early if already default" do
    pm = @pay_customer.payment_methods.create!(
      processor_id: "pm_123",
      payment_method_type: "card",
      default: true
    )

    # Should not call Stripe API
    ::Stripe::Customer.expects(:update).never

    pm.make_default!
  end

  test "make_default! handles multiple payment methods correctly" do
    # Create three payment methods
    pm1 = @pay_customer.payment_methods.create!(processor_id: "pm_1", payment_method_type: "card", default: true)
    pm2 = @pay_customer.payment_methods.create!(processor_id: "pm_2", payment_method_type: "card", default: false)
    pm3 = @pay_customer.payment_methods.create!(processor_id: "pm_3", payment_method_type: "card", default: false)

    # Mock Stripe API call
    ::Stripe::Customer.stubs(:update).returns(true)

    # Make pm3 the default
    pm3.make_default!

    # Verify all states
    pm1.reload
    pm2.reload
    pm3.reload
    refute pm1.default?
    refute pm2.default?
    assert pm3.default?
  end
end
