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
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_stripe_invoice))
    assert_equal pay_subscription, pay_charge.subscription
  end

  test "sync records tax from invoice" do
    @pay_customer.subscriptions.create!(processor_id: "sub_1234", name: "default", processor_plan: "some-plan", status: "active")
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_stripe_invoice))
    assert_equal 3_00, pay_charge.tax
  end

  test "sync records subtotal from invoice" do
    @pay_customer.subscriptions.create!(processor_id: "sub_1234", name: "default", processor_plan: "some-plan", status: "active")
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_stripe_invoice))
    assert_equal 21_49, pay_charge.subtotal
  end

  test "sync records total_tax_amounts from invoice" do
    @pay_customer.subscriptions.create!(processor_id: "sub_1234", name: "default", processor_plan: "some-plan", status: "active")
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_stripe_invoice))
    assert_equal "sales_tax", pay_charge.total_tax_amounts.first.dig("tax_rate", "tax_type")
  end

  private

  def fake_stripe_invoice(**values)
    values.reverse_merge!(
      subscription: "sub_1234",
      period_start: Time.current,
      period_end: Time.current,
      lines: {object: "list", data: [], has_more: false},
      subtotal: 21_49,
      tax: 3_00,
      total: 24_49,
      total_tax_amounts: [
        {
          amount: 2353,
          inclusive: false,
          tax_rate:
          {
            id: "txr_1KOpM7KXBGcbgpbZB0Op4prs",
            object: "tax_rate",
            active: false,
            country: "US",
            created: 1643833387,
            description: nil,
            display_name: "Sales Tax",
            inclusive: false,
            jurisdiction: "Louisiana",
            livemode: false,
            metadata: {},
            percentage: 9.45,
            state: "LA",
            tax_type: "sales_tax"
          }
        }
      ],
      discounts: ["di_1KgYwKKXBGcbgpbZXaYJPeyI"],
      total_discount_amounts: [
        {amount: 12450, discount: {id: "di_1KgYwKKXBGcbgpbZXaYJPeyI", object: "discount", checkout_session: nil, coupon: {id: "upI7E8nG", object: "coupon", amount_off: nil, created: 1648059609, currency: nil, duration: "forever", duration_in_month: nil, livemode: false, max_redemptions: nil, metadata: {}, name: "Half Off", percent_off: 50.0, redeem_by: nil, times_redeemed: 3, valid: true}, customer: "cus_LNFszTN0gcJ4RH", end: nil, invoice: nil, invoice_item: "ii_1KgYwHKXBGcbgpbZVuQ152QU", promotion_code: nil, start: 1648060185, subscription: nil}}
      ]
    )
    ::Stripe::Invoice.construct_from(values)
  end

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
