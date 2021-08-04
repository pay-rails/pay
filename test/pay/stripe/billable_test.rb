require "test_helper"

class Pay::Stripe::BillableTest < ActiveSupport::TestCase
  setup do
    @user = users(:stripe)
    @pay_customer = @user.payment_processor
    @pay_customer.update(processor_id: nil)
  end

  test "stripe creates customer and assigns processor_id" do
    assert_nil @pay_customer.processor_id
    @pay_customer.customer
    assert_not_nil @pay_customer.processor_id
  end

  test "stripe creates customer when no processor id" do
    assert_nil @pay_customer.processor_id
    @pay_customer.payment_method_token = payment_method
    @pay_customer.customer
    assert_not_nil @pay_customer.processor_id
    assert_equal "card", @pay_customer.data["kind"]
    assert_equal "Visa", @pay_customer.data["type"]
    assert_equal "4242", @pay_customer.data["last4"]
  end

  test "stripe can create a charge" do
    @pay_customer.payment_method_token = payment_method
    charge = @pay_customer.charge(2900)
    assert_equal Pay::Charge, charge.class
    assert_equal 2900, charge.amount
  end

  test "stripe handles card declined" do
    @pay_customer.payment_method_token = "pm_card_chargeDeclined"
    assert_raises(Pay::Stripe::Error) { @pay_customer.charge(2900) }
  end

  test "stripe raises action required error when SCA required" do
    exception = assert_raises(Pay::ActionRequired) {
      @pay_customer.payment_method_token = sca_payment_method
      @pay_customer.charge(2900)
    }
    assert_equal "This payment attempt failed because additional action is required before it can be completed.", exception.message
  end

  test "stripe can create a subscription" do
    @pay_customer.payment_method_token = payment_method
    @pay_customer.subscribe(name: "default", plan: "small-monthly")

    assert @pay_customer.subscribed?
    assert_equal "default", @pay_customer.subscription.name
    assert_equal "small-monthly", @pay_customer.subscription.processor_plan
  end

  test "stripe can swap a subscription" do
    @pay_customer.payment_method_token = payment_method
    subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    subscription.swap("small-annual")
    assert @pay_customer.subscribed?
    assert_equal "default", @pay_customer.subscription.name
    assert_equal "small-annual", @pay_customer.subscription.processor_plan
  end

  test "stripe fails when subscribing with no payment method" do
    exception = assert_raises(Pay::Stripe::Error) {
      @pay_customer.subscribe(name: "default", plan: "small-monthly")
    }
    assert_equal "This customer has no attached payment source or default payment method.", exception.message
  end

  test "stripe fails when subscribing with SCA card" do
    exception = assert_raises(Pay::ActionRequired) {
      @pay_customer.payment_method_token = sca_payment_method
      @pay_customer.subscribe(name: "default", plan: "small-monthly")
    }

    assert_equal "This payment attempt failed because additional action is required before it can be completed.", exception.message
  end

  test "stripe can update card" do
    @pay_customer.update_card payment_method

    assert_equal "card", @pay_customer.data["kind"]
    assert_equal "Visa", @pay_customer.data["type"]
    assert_nil @pay_customer.payment_method_token

    @pay_customer.update_card "pm_card_discover"
    assert_equal "Discover", @pay_customer.data["type"]
  end

  test "stripe can retrieve subscription" do
    @pay_customer.update_card(payment_method)
    subscription = ::Stripe::Subscription.create(plan: "small-monthly", customer: @pay_customer.processor_id)
    assert_equal @pay_customer.processor_subscription(subscription.id), subscription
  end

  test "can create an invoice" do
    @pay_customer.update_card(payment_method)

    ::Stripe::InvoiceItem.create(
      customer: @pay_customer.processor_id,
      amount: 1000,
      currency: "usd",
      description: "One-time setup fee"
    )

    assert_equal 1000, @pay_customer.invoice!.total
  end

  test "stripe card gets updated automatically when retrieving customer" do
    # This should trigger update_card
    @pay_customer.payment_method_token = payment_method
    @pay_customer.customer
    assert_equal "card", @pay_customer.data["kind"]
    assert_equal "Visa", @pay_customer.data["type"]
    assert_equal "4242", @pay_customer.data["last4"]
  end

  test "stripe creates with no card" do
    @pay_customer.customer
    assert_equal @pay_customer.processor, "stripe"
    assert_not_nil @pay_customer.processor_id
    assert_nil @pay_customer.data["card_last4"]
  end

  test "stripe email updates on change" do
    # Must already have a processor ID
    @pay_customer.customer # Sets customer ID
    Pay::CustomerSyncJob.expects(:perform_later).with(@pay_customer.id)
    @user.update(email: "mynewemail@example.org")
  end

  test "stripe handles exception when creating a customer" do
    @pay_customer.payment_method_token = "invalid"
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.customer }
    assert_equal "No such PaymentMethod: 'invalid'", exception.message
  end

  test "stripe handles exception when creating a charge" do
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.charge(0) }
    assert_equal "This value must be greater than or equal to 1.", exception.message
  end

  test "stripe handles exception when creating a subscription" do
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.subscribe plan: "invalid" }
    assert_equal "No such plan: 'invalid'", exception.message
  end

  test "stripe handles exception when updating a card" do
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.update_card("abcd") }
    assert_equal "No such PaymentMethod: 'abcd'", exception.message
  end

  test "stripe handles coupons" do
    @pay_customer.payment_method_token = payment_method
    subscription = @pay_customer.subscribe(plan: "small-monthly", coupon: "10BUCKS")
    assert_equal "10BUCKS", subscription.processor_subscription.discount.coupon.id
  end

  test "stripe trial period options" do
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      @pay_customer.payment_method_token = payment_method
      subscription = @pay_customer.subscribe(plan: "small-monthly", trial_period_days: 15)
      assert_equal "trialing", subscription.status
      assert_not_nil subscription.trial_ends_at
      assert subscription.trial_ends_at > 14.days.from_now
    end
  end

  test "stripe can create setup intent" do
    assert_nothing_raised do
      @pay_customer.create_setup_intent
    end
  end

  test "stripe can pass shipping information to charge" do
    @pay_customer.payment_method_token = payment_method
    charge = @pay_customer.charge(25_00, shipping: {
      name: "Recipient",
      address: {
        line1: "One Infinite Loop",
        city: "Cupertino",
        state: "CA"
      }
    })

    assert_equal "Cupertino", charge.processor_charge.shipping.address.city
  end

  test "stripe allows subscription quantities" do
    @pay_customer.payment_method_token = payment_method
    subscription = @pay_customer.subscribe(plan: "small-monthly", quantity: 10)
    assert_equal 10, subscription.processor_subscription.quantity
    assert_equal 10, subscription.quantity
  end

  test "stripe card is automatically updated on subscribe" do
    assert_nil @pay_customer.data
    @pay_customer.payment_method_token = "pm_card_amex"
    @pay_customer.subscribe
    assert_equal "card", @pay_customer.data["kind"]
  end

  test "stripe subscription and one time charge" do
    @pay_customer.payment_method_token = "pm_card_visa"
    @pay_customer.subscribe(
      name: "default",
      plan: "default",
      add_invoice_items: [
        {price: "price_1ILVZaKXBGcbgpbZQ26kgXWG"} # T-Shirt $15
      ]
    )

    invoice_id = Pay::Subscription.last.processor_subscription.latest_invoice
    invoice = ::Stripe::Invoice.retrieve(invoice_id)
    assert_equal 25_00, invoice.total
    assert_not_nil invoice.lines.data.find { |l| l.plan&.id == "default" }
    assert_not_nil invoice.lines.data.find { |l| l.price&.id == "price_1ILVZaKXBGcbgpbZQ26kgXWG" }
  end

  test "stripe saves currency on charge" do
    @pay_customer.payment_method_token = "pm_card_visa"
    charge = @pay_customer.charge(29_00)
    assert_equal "usd", charge.currency
  end

  private

  def payment_method
    @payment_method ||= "pm_card_visa"
  end

  def sca_payment_method
    @sca_payment_method ||= "pm_card_authenticationRequired"
  end

  def create_payment_method(options = {})
    defaults = {
      type: "card",
      billing_details: {name: "Jane Doe"},
      card: {
        number: "4242 4242 4242 4242",
        exp_month: 9,
        exp_year: Time.now.year + 5,
        cvc: 123
      }
    }

    ::Stripe::PaymentMethod.create(defaults.deep_merge(options))
  end
end
