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
    assert_equal "card", @pay_customer.default_payment_method.type
    assert_equal "Visa", @pay_customer.default_payment_method.brand
    assert_equal "4242", @pay_customer.default_payment_method.last4
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
    travel_to(VCR.current_cassette.originally_recorded_at || Time.current) do
      # We select the subscription by newest created_at, so we want to make sure existing subscriptions are in the past
      @pay_customer.subscriptions.update_all(created_at: 1.hour.ago)

      @pay_customer.payment_method_token = payment_method
      pay_subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")

      assert @pay_customer.subscribed?
      assert_equal pay_subscription, @pay_customer.subscription
    end
  end

  test "stripe subscribe also saves initial charge" do
    assert_difference "@pay_customer.charges.count" do
      @pay_customer.payment_method_token = payment_method
      @pay_customer.subscribe(name: "default", plan: "small-monthly")
    end

    assert @pay_customer.subscribed?
    assert_equal "Visa", @pay_customer.charges.last.brand
  end

  test "stripe can swap a subscription" do
    @pay_customer.payment_method_token = payment_method
    subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    subscription.swap("small-annual")
    assert_equal "default", subscription.name
    assert_equal "small-annual", subscription.processor_plan
  end

  test "stripe can swap a subscription and reset billing cycle" do
    @pay_customer.payment_method_token = payment_method
    subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    subscription.swap("small-annual", billing_cycle_anchor: "now")
    assert_equal "default", subscription.name
    assert_equal "small-annual", subscription.processor_plan
  end

  test "stripe can swap and invoice a subscription" do
    @pay_customer.payment_method_token = payment_method
    subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    subscription.swap_and_invoice("small-annual")
    assert_equal "default", subscription.name
    assert_equal "small-annual", subscription.processor_plan
  end

  test "stripe fails when subscribing with no payment method" do
    exception = assert_raises(Pay::Stripe::Error) {
      @pay_customer.subscribe(name: "default", plan: "small-monthly")
    }
    assert_match "This customer has no attached payment source or default payment method.", exception.message
  end

  test "stripe fails when subscribing with SCA card" do
    exception = assert_raises(Pay::ActionRequired) {
      @pay_customer.payment_method_token = sca_payment_method
      @pay_customer.subscribe(name: "default", plan: "small-monthly")
    }

    assert_equal "This payment attempt failed because additional action is required before it can be completed.", exception.message
  end

  test "stripe can update card" do
    @pay_customer.update_payment_method payment_method

    assert_equal "card", @pay_customer.default_payment_method.type
    assert_equal "Visa", @pay_customer.default_payment_method.brand
    assert_nil @pay_customer.payment_method_token

    @pay_customer.update_payment_method "pm_card_discover"
    assert_equal "Discover", @pay_customer.default_payment_method.brand
  end

  test "stripe can retrieve subscription" do
    @pay_customer.update_payment_method(payment_method)
    subscription = ::Stripe::Subscription.create(plan: "small-monthly", customer: @pay_customer.processor_id)
    assert_equal @pay_customer.processor_subscription(subscription.id), subscription
  end

  test "can create an invoice" do
    @pay_customer.update_payment_method(payment_method)

    ::Stripe::InvoiceItem.create(
      customer: @pay_customer.processor_id,
      amount: 1000,
      currency: "usd",
      description: "One-time setup fee"
    )

    assert_equal 1000, @pay_customer.invoice!.total
  end

  test "stripe card gets updated automatically when retrieving customer" do
    @pay_customer.payment_method_token = payment_method
    @pay_customer.customer
    assert_equal "card", @pay_customer.default_payment_method.type
    assert_equal "Visa", @pay_customer.default_payment_method.brand
    assert_equal "4242", @pay_customer.default_payment_method.last4
  end

  test "stripe creates with no card" do
    # Clear out any fixtures
    @pay_customer.payment_methods.destroy_all

    @pay_customer.customer
    assert_equal @pay_customer.processor, "stripe"
    assert_not_nil @pay_customer.processor_id
    assert_nil @pay_customer.default_payment_method
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
    assert_match "No such PaymentMethod: 'invalid'", exception.message
  end

  test "stripe handles exception when creating a charge" do
    @pay_customer.payment_methods.destroy_all
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.charge(0) }
    assert_equal "This value must be greater than or equal to 1.", exception.message
  end

  test "stripe handles exception when creating a subscription" do
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.subscribe plan: "invalid" }
    assert_equal "No such plan: 'invalid'", exception.message
  end

  test "stripe handles exception when updating a card" do
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.update_payment_method("abcd") }
    assert_match "No such PaymentMethod: 'abcd'", exception.message
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
    assert_equal "card", @pay_customer.default_payment_method.type
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

    invoice = Pay::Subscription.last.processor_subscription.latest_invoice
    assert_equal 25_00, invoice.total
    assert_not_nil invoice.lines.data.find { |l| l.plan&.id == "default" }
    assert_not_nil invoice.lines.data.find { |l| l.price&.id == "price_1ILVZaKXBGcbgpbZQ26kgXWG" }
  end

  test "stripe prices api" do
    price_id = "price_1JNJJkKXBGcbgpbZuOiH3XJK"
    @pay_customer.payment_method_token = "pm_card_visa"
    pay_subscription = @pay_customer.subscribe plan: price_id
    assert_equal price_id, pay_subscription.processor_plan
  end

  test "stripe saves currency on charge" do
    @pay_customer.payment_method_token = "pm_card_visa"
    charge = @pay_customer.charge(29_00)
    assert_equal "usd", charge.currency
  end

  test "stripe saves acss_debit" do
    pm = Stripe::PaymentMethod.create(type: "acss_debit", acss_debit: {account_number: "00123456789", institution_number: "000", transit_number: "11000"}, billing_details: {email: "test@example.org", name: "Test User"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "acss_debit", @pay_customer.default_payment_method.type
    assert_equal "STRIPE TEST BANK", @pay_customer.default_payment_method.bank
    assert_equal "6789", @pay_customer.default_payment_method.last4
  end

  test "stripe saves afterpay_clearpay" do
    pm = Stripe::PaymentMethod.create(type: "afterpay_clearpay", billing_details: {address: {line1: "1 Fake Street", city: "Cupertino", state: "CA", country: "US", postal_code: "95102"}, email: "test@example.org", name: "Test User"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "afterpay_clearpay", @pay_customer.default_payment_method.type
  end

  test "stripe saves alipay" do
    pm = Stripe::PaymentMethod.create(type: "alipay")
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "alipay", @pay_customer.default_payment_method.type
  end

  # Only available in Australia
  # test "stripe saves au_becs_debit" do
  #   pm = Stripe::PaymentMethod.create(type: "au_becs_debit", au_becs_debit: { account_number: "000123456", bsb_number: "000-000" }, billing_details: { email: "test@example.org", name: "Test User" })
  #   @pay_customer.save_payment_method(pm, default: true)
  #   assert_equal "au_becs_debit", @pay_customer.default_payment_method.type
  #   assert_equal "3456", @pay_customer.default_payment_method.last4
  # end

  # Merchant country should be among Bacs Debit supported countries: AT, BE, CH, DE, DK, ES, FI, FR, GB, IE, IT, LU, NL, NO, SE, PT
  # test "stripe saves bacs_debit" do
  #   pm = Stripe::PaymentMethod.create(type: "bacs_debit", bacs_debit: { account_number: "00012345", sort_code: "108800" }, billing_details: { email: "test@example.org" , name: "Test User", address: { line1: "1 Fake Street", city: "Cupertino", state: "CA", postal_code: 95102, country: "DE"}})
  #   @pay_customer.save_payment_method(pm, default: true)
  #   assert_equal "bacs_debit", @pay_customer.default_payment_method.type
  #   assert_equal "3456", @pay_customer.default_payment_method.last4
  # end

  test "stripe saves bancontact" do
    pm = Stripe::PaymentMethod.create(type: "bancontact", billing_details: {name: "Test User"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "bancontact", @pay_customer.default_payment_method.type
  end

  test "stripe saves boleto" do
    pm = Stripe::PaymentMethod.create(type: "boleto", boleto: {tax_id: "000.000.000-00"}, billing_details: {email: "test@example.org", name: "Test User", address: {line1: "1 Fake Street", city: "Salvador", state: "BA", country: "BR", postal_code: "41940-340"}})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "boleto", @pay_customer.default_payment_method.type
  end

  # Direct creation of PaymentMethods for type 'card_present' is disallowed.
  # test "stripe saves card_present" do
  #   pm = Stripe::PaymentMethod.create(type: "card_present")
  #   @pay_customer.save_payment_method(pm, default: true)
  #   assert_equal "eps", @pay_customer.default_payment_method.type
  #   assert_equal "bank_austria", @pay_customer.default_payment_method.bank
  # end

  test "stripe saves eps bank" do
    pm = Stripe::PaymentMethod.create(type: "eps", eps: {bank: "bank_austria"}, billing_details: {name: "Test User"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "eps", @pay_customer.default_payment_method.type
    assert_equal "bank_austria", @pay_customer.default_payment_method.bank
  end

  test "stripe saves fpx" do
    pm = Stripe::PaymentMethod.create(type: "fpx", fpx: {bank: "affin_bank"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "fpx", @pay_customer.default_payment_method.type
    assert_equal "affin_bank", @pay_customer.default_payment_method.bank
  end

  test "stripe saves giropay" do
    pm = Stripe::PaymentMethod.create(type: "giropay", billing_details: {name: "Test User"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "giropay", @pay_customer.default_payment_method.type
  end

  test "stripe saves grabpay" do
    pm = Stripe::PaymentMethod.create(type: "grabpay")
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "grabpay", @pay_customer.default_payment_method.type
  end

  test "stripe saves ideal" do
    pm = Stripe::PaymentMethod.create(type: "ideal", ideal: {bank: "abn_amro"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "ideal", @pay_customer.default_payment_method.type
    assert_equal "abn_amro", @pay_customer.default_payment_method.bank
  end

  # Direct creation of PaymentMethods for type 'interac_present' is disallowed.
  # test "stripe saves interac_present" do
  #   pm = Stripe::PaymentMethod.create(type: "interac_present", billing_details: { name: "Test User" })
  #   @pay_customer.save_payment_method(pm, default: true)
  #   assert_equal "interac_present", @pay_customer.default_payment_method.type
  #   assert_equal "abn_amro", @pay_customer.default_payment_method.bank
  # end

  test "stripe saves oxxo" do
    pm = Stripe::PaymentMethod.create(type: "oxxo", billing_details: {email: "test@example.org", name: "Test User"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "oxxo", @pay_customer.default_payment_method.type
  end

  test "stripe saves p24" do
    pm = Stripe::PaymentMethod.create(type: "p24", p24: {bank: "ing"}, billing_details: {email: "test@example.org"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "p24", @pay_customer.default_payment_method.type
    assert_equal "ing", @pay_customer.default_payment_method.bank
  end

  test "stripe saves sepa_debit" do
    pm = Stripe::PaymentMethod.create(type: "sepa_debit", sepa_debit: {iban: "DK5000400440116243"}, billing_details: {email: "test@example.org", name: "Test User"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "sepa_debit", @pay_customer.default_payment_method.type
    assert_equal "6243", @pay_customer.default_payment_method.last4
  end

  test "stripe saves sofort" do
    pm = Stripe::PaymentMethod.create(type: "sofort", sofort: {country: "DE"})
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "sofort", @pay_customer.default_payment_method.type
  end

  test "stripe saves wechat_pay" do
    pm = Stripe::PaymentMethod.create(type: "wechat_pay")
    @pay_customer.save_payment_method(pm, default: true)
    assert_equal "wechat_pay", @pay_customer.default_payment_method.type
  end

  test "stripe customer attributes proc" do
    pay_customer = pay_customers(:stripe)
    original_value = User.pay_stripe_customer_attributes
    attributes = {metadata: {foo: :bar}}

    User.pay_stripe_customer_attributes = ->(pay_customer) { attributes }
    assert attributes <= Pay::Stripe::Billable.new(pay_customer).customer_attributes

    # Clean up
    User.pay_stripe_customer_attributes = original_value
  end

  test "stripe customer attributes symbol" do
    pay_customer = pay_customers(:stripe)
    original_value = User.pay_stripe_customer_attributes

    User.pay_stripe_customer_attributes = :stripe_attributes
    expected_value = pay_customer.owner.stripe_attributes(pay_customer)
    assert expected_value <= Pay::Stripe::Billable.new(pay_customer).customer_attributes

    # Clean up
    User.pay_stripe_customer_attributes = original_value
  end

  test "stripe can pause and resume a subscription" do
    travel_to_cassette do
      @pay_customer.payment_method_token = payment_method
      @pay_subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")

      @pay_subscription.pause(behavior: "void", resumes_at: 1.month.from_now.to_i)
      assert @pay_subscription.paused?
      assert_equal "void", @pay_subscription.pause_behavior
      assert @pay_subscription.pause_resumes_at > 21.days.from_now

      # Ensure Stripe record is paused
      assert_equal "void", @pay_subscription.processor_subscription.pause_collection.behavior

      @pay_subscription.resume
      refute @pay_subscription.paused?
      assert_nil @pay_subscription.pause_behavior
      assert_nil @pay_subscription.pause_resumes_at

      # Ensure Stripe record is unpaused
      assert_nil @pay_subscription.processor_subscription.pause_collection
    end
  end

  test "stripe can authorize a charge" do
    @pay_customer.payment_method_token = payment_method
    charge = @pay_customer.authorize(29_00)
    assert_equal Pay::Charge, charge.class
    assert_equal 0, charge.amount_captured
  end

  test "stripe can capture an authorized charge" do
    @pay_customer.payment_method_token = payment_method
    charge = @pay_customer.authorize(29_00)
    assert_equal 0, charge.amount_captured

    charge = charge.capture
    assert charge.captured?
    assert_equal 29_00, charge.amount_captured
  end

  test "stripe can issue credit note for a refund for Stripe tax" do
    @pay_customer.payment_method_token = payment_method
    pay_subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    pay_subscription.charges.last.refund!(5_00)
    pay_subscription.payment_processor.reload!
    invoice = pay_subscription.subscription.latest_invoice
    assert_equal 5_00, invoice.post_payment_credit_notes_amount
    assert_equal 5_00, pay_subscription.charges.last.amount_refunded
  end

  test "sync_subscriptions" do
    @pay_customer.processor_id = "test_id"
    ::Stripe::Subscription.expects(:list).with({customer: @pay_customer.processor_id}, {}).returns([])
    @pay_customer.sync_subscriptions
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
