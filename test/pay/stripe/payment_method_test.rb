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

  private

  def fake_stripe_payment_method(**values)
    values.reverse_merge!(
      id: "pm_123",
      object: "payment_method",
      billing_details: {
        address: {
          city: nil,
          country: nil,
          line1: nil,
          line2: nil,
          postal_code: "42424",
          state: nil
        },
        email: "jenny@example.com",
        name: nil,
        phone: "+15555555555"
      },
      card: {
        brand: "visa",
        checks: {
          address_line1_check: nil,
          address_postal_code_check: nil,
          cvc_check: "pass"
        },
        country: "US",
        exp_month: 8,
        exp_year: 2024,
        fingerprint: "eLihtj2HTMlWeL7e",
        funding: "credit",
        generated_from: nil,
        last4: "4242",
        networks: {
          available: [
            "visa"
          ],
          preferred: nil
        },
        three_d_secure_usage: {
          supported: true
        },
        wallet: nil
      },
      created: 123456789,
      customer: "cus_1234",
      livemode: false,
      metadata: {
        order_id: "123456789"
      },
      type: "card"
    )
    ::Stripe::PaymentMethod.construct_from(values)
  end
end
