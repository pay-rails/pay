require "test_helper"

class Pay::Stripe::CustomerTest < ActiveSupport::TestCase
  setup do
    @user = users(:stripe)
    @pay_customer = @user.payment_processor
    @pay_customer.update(processor_id: nil)
  end

  test "stripe creates customer and assigns processor_id" do
    assert_nil @pay_customer.processor_id
    @pay_customer.api_record
    assert_not_nil @pay_customer.processor_id
  end

  test "stripe creates customer when no processor id" do
    assert_nil @pay_customer.processor_id
    @pay_customer.update_payment_method payment_method
    @pay_customer.api_record
    assert_not_nil @pay_customer.processor_id
    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "Visa", @pay_customer.default_payment_method.brand
    assert_equal "4242", @pay_customer.default_payment_method.last4
  end

  test "stripe can create a charge" do
    @pay_customer.update_payment_method payment_method
    charge = @pay_customer.charge(2900)
    assert_equal Pay::Stripe::Charge, charge.class
    assert_equal 2900, charge.amount
  end

  test "stripe handles card declined" do
    assert_raises(Pay::Stripe::Error) do
      @pay_customer.update_payment_method "pm_card_chargeDeclined"
    end
  end

  test "stripe raises action required error when SCA required" do
    exception = assert_raises(Pay::ActionRequired) do
      @pay_customer.update_payment_method sca_payment_method
      @pay_customer.charge(2900)
    end
    assert_equal "This payment attempt failed because additional action is required before it can be completed.",
      exception.message
  end

  test "stripe can create a subscription" do
    travel_to_cassette do
      # We select the subscription by newest created_at, so we want to make sure existing subscriptions are in the past
      @pay_customer.subscriptions.update_all(created_at: 1.hour.ago)

      @pay_customer.update_payment_method payment_method
      pay_subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")

      assert @pay_customer.subscribed?
      assert_equal pay_subscription, @pay_customer.subscription
    end
  end

  test "stripe subscribe also saves initial charge" do
    assert_difference "@pay_customer.charges.count" do
      @pay_customer.update_payment_method payment_method
      @pay_customer.subscribe(name: "default", plan: "small-monthly")
    end

    assert @pay_customer.subscribed?
    assert_equal "Visa", @pay_customer.charges.last.brand
  end

  test "stripe can swap a subscription" do
    @pay_customer.update_payment_method payment_method
    subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    subscription.swap("small-annual")
    assert_equal "default", subscription.name
    assert_equal "small-annual", subscription.processor_plan
  end

  test "stripe can swap a subscription and reset billing cycle" do
    @pay_customer.update_payment_method payment_method
    subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    subscription.swap("small-annual", billing_cycle_anchor: "now")
    assert_equal "default", subscription.name
    assert_equal "small-annual", subscription.processor_plan
  end

  test "stripe can swap and invoice a subscription" do
    @pay_customer.update_payment_method payment_method
    subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    subscription.swap_and_invoice("small-annual")
    assert_equal "default", subscription.name
    assert_equal "small-annual", subscription.processor_plan
  end

  test "stripe fails when subscribing with no payment method" do
    exception = assert_raises(Pay::Stripe::Error) do
      @pay_customer.subscribe(name: "default", plan: "small-monthly")
    end
    assert_match "This customer has no attached payment source or default payment method.", exception.message
  end

  test "stripe fails when subscribing with SCA card" do
    exception = assert_raises(Pay::ActionRequired) do
      @pay_customer.update_payment_method sca_payment_method
      @pay_customer.subscribe(name: "default", plan: "small-monthly")
    end

    assert_equal "This payment attempt failed because additional action is required before it can be completed.",
      exception.message
  end

  test "stripe can update card" do
    @pay_customer.update_payment_method payment_method

    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "Visa", @pay_customer.default_payment_method.brand

    @pay_customer.update_payment_method "pm_card_discover"
    assert_equal "Discover", @pay_customer.default_payment_method.brand
  end

  test "stripe can create an invoice" do
    @pay_customer.update_payment_method(payment_method)

    ::Stripe::InvoiceItem.create(
      customer: @pay_customer.processor_id,
      amount: 1000,
      currency: "usd",
      description: "One-time setup fee"
    )

    assert_equal 1000, @pay_customer.invoice!(pending_invoice_items_behavior: :include).total
  end

  test "stripe card gets updated automatically when retrieving customer" do
    @pay_customer.update_payment_method payment_method
    @pay_customer.api_record
    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "Visa", @pay_customer.default_payment_method.brand
    assert_equal "4242", @pay_customer.default_payment_method.last4
  end

  test "stripe creates with no card" do
    # Clear out any fixtures
    @pay_customer.payment_methods.destroy_all

    @pay_customer.api_record
    assert_equal @pay_customer.processor, "stripe"
    assert_not_nil @pay_customer.processor_id
    assert_nil @pay_customer.default_payment_method
  end

  test "stripe email updates on change" do
    # Must already have a processor ID
    @pay_customer.api_record # Sets customer ID
    Pay::CustomerSyncJob.expects(:perform_later).with(@pay_customer.id)
    @user.update(email: "mynewemail@example.org")
  end

  test "stripe handles exception when creating a customer" do
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.update_payment_method "invalid" }
    assert_match "No such PaymentMethod: 'invalid'", exception.message
  end

  test "stripe handles exception when creating a charge" do
    @pay_customer.payment_methods.destroy_all
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.charge(0) }
    assert_match "The amount must be greater than or equal to", exception.message
  end

  test "stripe handles exception when creating a subscription" do
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.subscribe plan: "invalid" }
    assert_match "No such price: 'invalid'", exception.message
  end

  test "stripe handles exception when updating a card" do
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.update_payment_method("abcd") }
    assert_match "No such PaymentMethod: 'abcd'", exception.message
  end

  test "stripe handles coupons" do
    @pay_customer.update_payment_method payment_method
    subscription = @pay_customer.subscribe(plan: "small-monthly", discounts: [{coupon: "10OFF"}])
    assert_equal "10OFF", subscription.stripe_object.discounts.first.source.coupon
  end

  test "stripe trial period options" do
    travel_to_cassette do
      @pay_customer.update_payment_method payment_method
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
    @pay_customer.update_payment_method payment_method
    charge = @pay_customer.charge(25_00, shipping: {
      name: "Recipient",
      address: {
        line1: "One Infinite Loop",
        city: "Cupertino",
        state: "CA"
      }
    })

    assert_equal "Cupertino", charge.api_record.shipping.address.city
  end

  test "stripe allows subscription quantities" do
    @pay_customer.update_payment_method payment_method
    subscription = @pay_customer.subscribe(plan: "small-monthly", quantity: 10)
    assert_equal 10, subscription.api_record.quantity
    assert_equal 10, subscription.quantity
  end

  test "stripe card is automatically updated on subscribe" do
    assert_nil @pay_customer.data
    @pay_customer.update_payment_method "pm_card_amex"
    @pay_customer.subscribe
    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
  end

  test "stripe subscription and one time charge" do
    @pay_customer.update_payment_method "pm_card_visa"
    @pay_customer.subscribe(
      name: "default",
      plan: "default",
      add_invoice_items: [
        {price: "price_1ILVZaKXBGcbgpbZQ26kgXWG"} # T-Shirt $15
      ]
    )

    invoice = Pay::Subscription.last.api_record.latest_invoice
    assert_equal 25_00, invoice.total
    assert_not_nil invoice.lines.data.find { |l| l.pricing.price_details.price == "default" }
    assert_not_nil invoice.lines.data.find { |l| l.pricing.price_details.price == "price_1ILVZaKXBGcbgpbZQ26kgXWG" }
  end

  test "stripe prices api" do
    price_id = "price_1JNJJkKXBGcbgpbZuOiH3XJK"
    @pay_customer.update_payment_method "pm_card_visa"
    pay_subscription = @pay_customer.subscribe plan: price_id
    assert_equal price_id, pay_subscription.processor_plan
  end

  test "stripe saves currency on charge" do
    @pay_customer.update_payment_method "pm_card_visa"
    charge = @pay_customer.charge(29_00)
    assert_equal "usd", charge.currency
  end

  # Payment method types Stripe lets the test API create directly, with the params to create one and the
  # details Pay should record from it. au_becs_debit, bacs_debit, card_present and interac_present can't be
  # created this way, so they aren't covered.
  STRIPE_PAYMENT_METHOD_TYPES = {
    "acss_debit" => [{acss_debit: {account_number: "000123456789", institution_number: "000", transit_number: "11000"}, billing_details: {email: "test@example.org", name: "Test User"}}, {bank: "STRIPE TEST BANK", last4: "6789"}],
    "afterpay_clearpay" => [{billing_details: {address: {line1: "1 Fake Street", city: "Cupertino", state: "CA", country: "US", postal_code: "95102"}, email: "test@example.org", name: "Test User"}}, {}],
    "alipay" => [{}, {}],
    "bancontact" => [{billing_details: {name: "Test User"}}, {}],
    "boleto" => [{boleto: {tax_id: "000.000.000-00"}, billing_details: {email: "test@example.org", name: "Test User", address: {line1: "1 Fake Street", city: "Salvador", state: "BA", country: "BR", postal_code: "41940-340"}}}, {}],
    "eps" => [{eps: {bank: "bank_austria"}, billing_details: {name: "Test User"}}, {bank: "bank_austria"}],
    "fpx" => [{fpx: {bank: "affin_bank"}}, {bank: "affin_bank"}],
    "giropay" => [{billing_details: {name: "Test User"}}, {}],
    "grabpay" => [{}, {}],
    "ideal" => [{ideal: {bank: "abn_amro"}}, {bank: "abn_amro"}],
    "oxxo" => [{billing_details: {email: "test@example.org", name: "Test User"}}, {}],
    "p24" => [{p24: {bank: "ing"}, billing_details: {email: "test@example.org"}}, {bank: "ing"}],
    "sepa_debit" => [{sepa_debit: {iban: "DK5000400440116243"}, billing_details: {email: "test@example.org", name: "Test User"}}, {last4: "6243"}],
    "sofort" => [{sofort: {country: "DE"}}, {}],
    "wechat_pay" => [{}, {}]
  }

  STRIPE_PAYMENT_METHOD_TYPES.each do |type, (params, expected)|
    test "stripe saves #{type}" do
      payment_method = Stripe::PaymentMethod.create(type: type, **params)
      @pay_customer.save_payment_method(payment_method, default: true)

      assert_equal type, @pay_customer.default_payment_method.payment_method_type
      expected.each do |attribute, value|
        assert_equal value, @pay_customer.default_payment_method.public_send(attribute), attribute
      end
    end
  end

  test "stripe customer attributes proc" do
    original_value = User.pay_stripe_customer_attributes

    pay_customer = pay_customers(:stripe)
    attributes = {metadata: {foo: :bar}}

    User.pay_stripe_customer_attributes = ->(pay_customer) { attributes }
    assert attributes <= pay_customer.api_record_attributes
  ensure
    User.pay_stripe_customer_attributes = original_value
  end

  test "stripe customer attributes symbol" do
    original_value = User.pay_stripe_customer_attributes
    pay_customer = pay_customers(:stripe)

    User.pay_stripe_customer_attributes = :stripe_attributes
    expected_value = pay_customer.owner.stripe_attributes(pay_customer)
    assert expected_value <= pay_customer.api_record_attributes
  ensure
    User.pay_stripe_customer_attributes = original_value
  end

  test "stripe can pause and resume a subscription" do
    travel_to_cassette do
      @pay_customer.update_payment_method(payment_method)
      @pay_subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")

      @pay_subscription.pause(behavior: "void", resumes_at: 1.month.from_now.to_i)
      assert @pay_subscription.paused?
      assert_equal "void", @pay_subscription.pause_behavior
      assert @pay_subscription.pause_resumes_at > 21.days.from_now

      # Ensure Stripe record is paused
      assert_equal "void", @pay_subscription.api_record.pause_collection.behavior

      @pay_subscription.resume
      refute @pay_subscription.paused?
      assert_nil @pay_subscription.pause_behavior
      assert_nil @pay_subscription.pause_resumes_at

      # Ensure Stripe record is unpaused
      assert_nil @pay_subscription.api_record.pause_collection
    end
  end

  test "stripe can authorize a charge" do
    @pay_customer.update_payment_method payment_method
    charge = @pay_customer.authorize(29_00)
    assert_equal Pay::Stripe::Charge, charge.class
    assert_equal 0, charge.amount_captured
  end

  test "stripe can capture an authorized charge" do
    @pay_customer.update_payment_method payment_method
    charge = @pay_customer.authorize(29_00)
    assert_equal 0, charge.amount_captured

    charge = charge.capture
    assert charge.captured?
    assert_equal 29_00, charge.amount_captured
  end

  test "stripe can issue credit note for a refund for Stripe tax" do
    @pay_customer.update_payment_method payment_method
    pay_subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    # InvoicePayments aren't created immediately, so we must wait until they're available to create a Credit Note
    # Pay::Stripe::Error: (Status 400) (Request req_t6t14FGEokRygN) You can only create a refund if the invoice has a charge associated with it.
    sleep 1
    pay_subscription.charges.last.refund!(5_00)
    pay_subscription.api_record = nil
    invoice = pay_subscription.api_record.latest_invoice
    assert_equal 5_00, invoice.post_payment_credit_notes_amount
    assert_equal 5_00, pay_subscription.charges.last.amount_refunded
  end

  test "stripe sync_subscriptions" do
    @pay_customer.processor_id = "test_id"
    ::Stripe::Subscription.expects(:list).with({customer: @pay_customer.processor_id}, {}).returns([])
    @pay_customer.sync_subscriptions
  end

  test "stripe sync_subscriptions passes the stripe_account through" do
    @pay_customer.update!(processor_id: "cus_1234", stripe_account: "acct_123")
    subscriptions = ::Stripe::ListObject.construct_from(object: "list", has_more: false, data: [{id: "sub_1", object: "subscription"}])
    ::Stripe::Subscription.expects(:list).with({customer: "cus_1234"}, {stripe_account: "acct_123"}).returns(subscriptions)
    Pay::Stripe::Subscription.expects(:sync).with("sub_1", stripe_account: "acct_123")
    @pay_customer.sync_subscriptions
  end

  test "stripe create_meter_event sends the request to the connected account" do
    @pay_customer.update!(processor_id: "cus_1234", stripe_account: "acct_123")
    ::Stripe::Billing::MeterEvent.expects(:create).with({event_name: :api_request, payload: {stripe_customer_id: "cus_1234", value: 1}}, {stripe_account: "acct_123"})
    @pay_customer.create_meter_event(:api_request, payload: {value: 1})
  end

  test "stripe retry_past_due_subscriptions! pays open invoices of past_due subscriptions" do
    @pay_customer.update!(processor_id: "cus_1234")
    pay_subscriptions(:stripe).update!(status: :past_due)
    ::Stripe::Invoice.expects(:list).with({subscription: "sub_1", status: :open, expand: ["data.payments"]}, {}).returns(::Stripe::ListObject.construct_from(object: "list", has_more: false, data: []))

    @pay_customer.retry_past_due_subscriptions!
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
