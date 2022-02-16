require "test_helper"

class Pay::Stripe::ChargeTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:stripe)
  end

  test "sync returns Pay::Charge" do
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge)
    assert pay_charge.is_a?(Pay::Charge)
  end

  test "sync stores charge metadata" do
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge)
    assert_equal({"license_id" => 1}, pay_charge.metadata)
  end

  test "sync stripe charge by ID" do
    assert_difference "Pay::Charge.count" do
      ::Stripe::Charge.stubs(:retrieve).returns(fake_stripe_charge)
      Pay::Stripe::Charge.sync("123")
    end
  end

  test "sync stripe charge ignores when customer is missing" do
    assert_no_difference "Pay::Charge.count" do
      Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(customer: "missing"))
    end
  end

  test "sync associates charge with stripe subscription" do
    pay_subscription = @pay_customer.subscriptions.create!(processor_id: "sub_1234", name: "default", processor_plan: "some-plan", status: "active")
    fake_invoice = ::Stripe::Invoice.construct_from(subscription: "sub_1234", period_start: Time.current, period_end: Time.current, lines: { object: "list", data: [], has_more: false})
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_invoice))
    assert_equal pay_subscription, pay_charge.subscription
  end

  private

  def fake_stripe_charge(**values)
    values.reverse_merge!(
      id: "ch_123",
      customer: "cus_1234",
      amount: 19_00,
      amount_refunded: nil,
      application_fee_amount: 0,
      created: 1546332337,
      currency: "usd",
      invoice: nil,
      payment_method_details: {
        card: {
          exp_month: 1,
          exp_year: 2021,
          last4: "4242",
          brand: "Visa"
        },
        type: "card"
      },
      metadata: {
        license_id: 1
      }
    )
    ::Stripe::Charge.construct_from(values)
  end
end
