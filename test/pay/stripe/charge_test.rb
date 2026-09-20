require "test_helper"

class Pay::Stripe::ChargeTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:stripe)
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

  test "sync associates charge with stripe subscription" do
    ::Stripe::InvoicePayment.stubs(:list).returns(::Stripe::ListObject.construct_from(object: :list, data: [fake_stripe_invoice_payment]))
    ::Stripe::Invoice.stubs(:retrieve).returns(fake_stripe_invoice_payment.invoice)
    pay_subscription = @pay_customer.subscriptions.create!(processor_id: "sub_1234", name: "default", processor_plan: "some-plan", status: "active")
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_stripe_invoice))
    assert_equal pay_subscription, pay_charge.subscription
  end

  test "sync records stripe invoice" do
    ::Stripe::InvoicePayment.stubs(:list).returns(::Stripe::ListObject.construct_from(object: :list, data: [fake_stripe_invoice_payment]))
    ::Stripe::Invoice.stubs(:retrieve).returns(fake_stripe_invoice_payment.invoice)
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_stripe_invoice))
    assert_instance_of ::Stripe::Invoice, pay_charge.stripe_invoice
    assert_equal "in_1234", pay_charge.stripe_invoice.id
  end

  test "sync records stripe receipt_url" do
    ::Stripe::InvoicePayment.stubs(:list).returns(::Stripe::ListObject.construct_from(object: :list, data: [fake_stripe_invoice_payment]))
    ::Stripe::Invoice.stubs(:retrieve).returns(fake_stripe_invoice_payment.invoice)
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
    ::Stripe::Invoice.stubs(:retrieve).returns(fake_stripe_invoice_payment.invoice)
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
    ::Stripe::Invoice.stubs(:retrieve).returns(fake_stripe_invoice_payment.invoice)
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge)
    assert_instance_of ::Stripe::BalanceTransaction, pay_charge.stripe_object.balance_transaction
  end

  test "sync stripe invoice discounts and coupons" do
    @pay_customer.update(processor_id: nil)
    @pay_customer.update_payment_method payment_method
    invoice = ::Stripe::Invoice.create(customer: @pay_customer.processor_id)
    ::Stripe::InvoiceItem.create(customer: @pay_customer.processor_id, invoice: invoice.id, amount: 1900, discounts: [{coupon: "sirmAxRi"}])
    invoice.pay
    invoice_payments = ::Stripe::InvoicePayment.list(invoice: invoice.id)
    charge = Pay::Stripe::Charge.sync_payment_intent(invoice_payments.first.payment.payment_intent)
    assert_equal "sirmAxRi", charge.stripe_invoice.total_discount_amounts.first.discount.source.coupon.id
    assert_equal 50.0, charge.stripe_invoice.total_discount_amounts.first.discount.source.coupon.percent_off
    # Ensure PDF renders with discounts
    assert_nothing_raised { charge.pdf_line_items }
  end

  test "sync uses the customer's stripe_account for invoice lookups when none is given" do
    @pay_customer.update!(stripe_account: "acct_123")
    ::Stripe::InvoicePayment.expects(:list).with(anything, {stripe_account: "acct_123"}).returns(::Stripe::ListObject.construct_from(object: :list, data: []))
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge)
    assert_equal "acct_123", pay_charge.stripe_account
  end

  test "sync! defaults to the charge's stripe_account" do
    pay_charge = @pay_customer.charges.create!(processor_id: "ch_123", amount: 19_00, stripe_account: "acct_123")
    Pay::Stripe::Charge.expects(:sync).with("ch_123", stripe_account: "acct_123")
    pay_charge.sync!
  end

  private

  def payment_method
    @payment_method ||= "pm_card_visa"
  end
end
