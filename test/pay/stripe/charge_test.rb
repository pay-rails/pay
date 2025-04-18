require "test_helper"

class Pay::Stripe::ChargeTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:stripe)
  end

  test "sync returns Pay::Charge" do
    ::Stripe::InvoicePayment.stubs(:list).returns([])
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge)
    assert pay_charge.is_a?(Pay::Charge)
  end

  test "sync stores charge metadata" do
    ::Stripe::InvoicePayment.stubs(:list).returns([])
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge)
    assert_equal({"license_id" => 1}, pay_charge.metadata)
  end

  test "sync stripe charge by ID" do
    assert_difference "Pay::Charge.count" do
      ::Stripe::InvoicePayment.stubs(:list).returns([])
      ::Stripe::Charge.stubs(:retrieve).returns(fake_stripe_charge)
      Pay::Stripe::Charge.sync("123")
    end
  end

  test "sync stripe charge ignores when customer is missing" do
    assert_no_difference "Pay::Charge.count" do
      Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(customer: "missing"))
    end
  end

  test "stripe sync skips charge without customer" do
    @pay_customer.update!(processor_id: nil)
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(customer: nil))
    assert_nil pay_charge
  end

  test "sync stripe charge ignores when customer is nil" do
    assert_no_difference "Pay::Charge.count" do
      Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(customer: nil))
    end
  end

  test "sync associates charge with stripe subscription" do
    ::Stripe::InvoicePayment.stubs(:list).returns(::Stripe::ListObject.construct_from(object: :list, data: [fake_stripe_invoice_payment]))
    pay_subscription = @pay_customer.subscriptions.create!(processor_id: "sub_1234", name: "default", processor_plan: "some-plan", status: "active")
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_stripe_invoice))
    assert_equal pay_subscription, pay_charge.subscription
  end

  test "sync records stripe invoice" do
    ::Stripe::InvoicePayment.stubs(:list).returns(::Stripe::ListObject.construct_from(object: :list, data: [fake_stripe_invoice_payment]))
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_stripe_invoice))
    assert_instance_of ::Stripe::Invoice, pay_charge.stripe_invoice
    assert_equal "in_1234", pay_charge.stripe_invoice.id
  end

  test "sync records stripe receipt_url" do
    ::Stripe::InvoicePayment.stubs(:list).returns(::Stripe::ListObject.construct_from(object: :list, data: [fake_stripe_invoice_payment]))
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge)
    assert_equal "https://pay.stripe.com/receipts/test_receipt", pay_charge.stripe_receipt_url
  end

  test "stripe performing multiple refunds increments total refund amount" do
    @pay_customer.update(processor_id: nil)
    @pay_customer.update_payment_method payment_method
    charge = @pay_customer.charge(30_00)
    charge.refund!(10_00)
    charge.refund!(5_00)
    assert_equal 15_00, charge.amount_refunded
  end

  test "sync stripe charge with Link" do
    ::Stripe::InvoicePayment.stubs(:list).returns(::Stripe::ListObject.construct_from(object: :list, data: [fake_stripe_invoice_payment]))
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(
      payment_method: "pm_0Mt5J5NFr9vQLFLbmIyjBdIM",
      payment_method_details: {
        link: {
          country: "DE"
        },
        type: "link"
      }
    ))

    assert_equal "link", pay_charge.payment_method_type
  end

  test "sync stripe charge balance_transaction" do
    ::Stripe::InvoicePayment.stubs(:list).returns(::Stripe::ListObject.construct_from(object: :list, data: [fake_stripe_invoice_payment]))
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge)
    assert_instance_of ::Stripe::BalanceTransaction, pay_charge.stripe_object.balance_transaction
  end

  private

  def fake_stripe_invoice_payment(**values)
    values.reverse_merge!(
      id: "inpay_1M3USa2eZvKYlo2CBjuwbq0N",
      object: "invoice_payment",
      amount_paid: 2000,
      amount_requested: 2000,
      created: 1391288554,
      currency: "usd",
      invoice: fake_stripe_invoice,
      is_default: true,
      livemode: false,
      payment: {
        type: "payment_intent",
        payment_intent: "pi_103Q0w2eZvKYlo2C364X582Z"
      },
      status: "paid",
      status_transitions: {
        canceled_at: nil,
        paid_at: 1391288554
      }
    )
    ::Stripe::InvoicePayment.construct_from(values)
  end

  def fake_stripe_invoice(**values)
    values.reverse_merge!(
      id: "in_1234",
      parent: {
        subscription_details: {
          subscription: "sub_1234"
        }
      },
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
      amount_captured: 19_00,
      amount_refunded: nil,
      application_fee_amount: 0,
      balance_transaction: {
        id: "txn_1MiN3gLkdIwHu7ixxapQrznl",
        object: "balance_transaction",
        amount: -400,
        available_on: 1678043844,
        created: 1678043844,
        currency: "usd",
        description: nil,
        exchange_rate: nil,
        fee: 0,
        fee_details: [],
        net: -400,
        reporting_category: "transfer",
        source: "tr_1MiN3gLkdIwHu7ixNCZvFdgA",
        status: "available",
        type: "transfer"
      },
      created: 1546332337,
      currency: "usd",
      invoice: nil,
      payment_intent: "pm_1234",
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
      },
      refunds: {
        object: "list",
        data: [],
        has_more: false,
        total_count: 0,
        url: ""
      },
      receipt_url: "https://pay.stripe.com/receipts/test_receipt"
    )
    ::Stripe::Charge.construct_from(values)
  end

  def payment_method
    @payment_method ||= "pm_card_visa"
  end
end
