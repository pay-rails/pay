require "test_helper"

class Pay::Braintree::CustomerTest < ActiveSupport::TestCase
  setup do
    @pay_customer = Pay::Braintree::Customer.create!(processor: :braintree, owner: users(:none))
  end

  test "braintree customer" do
    pay_customer = pay_customers(:braintree)
    pay_customer.update!(processor_id: nil)

    braintree_customer = pay_customer.api_record
    assert braintree_customer.id.present?
    assert_equal pay_customer.email, braintree_customer.email
  end

  test "customer attributes proc" do
    original_value = User.pay_braintree_customer_attributes

    attributes = {metadata: {foo: :bar}}
    User.pay_braintree_customer_attributes = ->(pay_customer) { attributes }

    assert attributes <= pay_customers(:braintree).api_record_attributes
  ensure
    User.pay_braintree_customer_attributes = original_value
  end

  test "braintree customer attributes symbol" do
    original_value = User.pay_braintree_customer_attributes

    pay_customer = pay_customers(:braintree)
    User.pay_braintree_customer_attributes = :braintree_attributes

    assert pay_customer.owner.braintree_attributes(pay_customer) <= pay_customer.api_record_attributes
  ensure
    User.pay_braintree_customer_attributes = original_value
  end

  test "braintree can store card" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    assert_equal "Visa", @pay_customer.default_payment_method.brand
  end

  test "braintree fails with invalid cards" do
    # This requires Card Verification to be enabled in the Braintree account
    err = assert_raises(Pay::Braintree::Error) { @pay_customer.update_payment_method "fake-processor-declined-visa-nonce" }
    assert_equal "Do Not Honor", err.message
  end

  test "braintree can update card" do
    @pay_customer.update_payment_method "fake-valid-discover-nonce"
    assert_equal "Discover", @pay_customer.default_payment_method.brand
  end

  test "braintree can charge card with credit card" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "card", charge.payment_method_type
    assert_equal "Visa", charge.brand
  end

  test "braintree can charge card with Google Pay Card" do
    # If Braintree ever introduces fake google pay nonces, we can update this
    @pay_customer.update_payment_method "fake-android-pay-visa-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "card", charge.payment_method_type
    assert_equal "Visa", charge.brand
  end

  test "braintree can charge card with Venmo" do
    @pay_customer.update_payment_method "fake-venmo-account-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "venmo", charge.payment_method_type
    assert_equal "Venmo", charge.brand
  end

  test "braintree update Apple Pay Card" do
    @pay_customer.update_payment_method "fake-apple-pay-visa-nonce"
    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "Apple Pay - Visa", @pay_customer.default_payment_method.brand
  end

  test "braintree update Google Pay Card" do
    # If Braintree ever introduces fake google pay nonces, we can update this
    @pay_customer.update_payment_method "fake-android-pay-visa-nonce"
    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "Visa", @pay_customer.default_payment_method.brand
  end

  test "braintree update PayPal Account" do
    @pay_customer.update_payment_method "fake-paypal-billing-agreement-nonce"
    assert_equal "paypal", @pay_customer.default_payment_method.payment_method_type
    assert_equal "PayPal", @pay_customer.default_payment_method.brand
  end

  test "braintree update Venmo Account" do
    @pay_customer.update_payment_method "fake-venmo-account-nonce"
    assert_equal "venmo", @pay_customer.default_payment_method.payment_method_type
    assert_equal "Venmo", @pay_customer.default_payment_method.brand
  end

  test "braintree fails with paypal processor declined" do
    @pay_customer.update_payment_method "fake-paypal-billing-agreement-nonce"
    assert_raises(Pay::Braintree::Error) { @pay_customer.charge(5001_01) }
  end

  test "braintree can create a subscription" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    @pay_customer.subscribe
    assert @pay_customer.subscribed?
  end

  test "braintree email changed" do
    # Must already have a processor ID
    @pay_customer.update(processor_id: "fake")
    assert_enqueued_with(job: Pay::CustomerSyncJob, args: [@pay_customer.id]) do
      @pay_customer.owner.update(email: "mynewemail@example.org")
    end
  end

  test "braintree trial period options" do
    travel_to_cassette do
      @pay_customer.update_payment_method "fake-valid-visa-nonce"
      subscription = @pay_customer.subscribe(trial_period_days: 15)
      # Braintree subscriptions don't use trialing status for simplicity
      assert_equal "active", subscription.status
      assert_not_nil subscription.trial_ends_at
      # Time.zone may not match the timezone in your Braintree account, so we'll be lenient on this assertion
      assert subscription.trial_ends_at > 14.days.from_now
    end
  end

  test "braintree saves transactions without losing a cent" do
    transaction = Braintree::Transaction._new(Pay.braintree_gateway, id: "abc", amount: "19.99", currency_iso_code: "USD", payment_instrument_type: "unknown")
    assert_equal 19_99, @pay_customer.save_transaction(transaction).amount
  end

  test "braintree saves the service fee in cents" do
    transaction = Braintree::Transaction._new(Pay.braintree_gateway, id: "abc", amount: "19.99", service_fee_amount: "1.50", currency_iso_code: "USD", payment_instrument_type: "unknown")
    assert_equal 1_50, @pay_customer.save_transaction(transaction).application_fee_amount
  end

  test "braintree saves zero-decimal currency amounts in the currency's subunit" do
    transaction = Braintree::Transaction._new(Pay.braintree_gateway, id: "abc", amount: "1000", service_fee_amount: "50", currency_iso_code: "JPY", payment_instrument_type: "unknown")
    charge = @pay_customer.save_transaction(transaction)
    assert_equal 1000, charge.amount
    assert_equal 50, charge.application_fee_amount
  end

  test "braintree charges zero-decimal currencies in the currency's main unit" do
    @pay_customer.update!(processor_id: "abc")
    transaction = Braintree::Transaction._new(Pay.braintree_gateway, id: "abc", amount: "1000", currency_iso_code: "JPY", payment_instrument_type: "unknown")
    ::Braintree::TransactionGateway.any_instance.expects(:sale).with(has_entry(:amount, "1000")).returns(stub(success?: true, transaction: transaction))
    assert_equal 1000, @pay_customer.charge(1000, currency: "jpy").amount
  end

  # $2000.00 - 2999.99 returns a Processor Declined
  # https://developers.braintreepayments.com/reference/general/testing/ruby#amount-200000-300099
  test "braintree fails charges with invalid cards" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    err = assert_raises(Pay::Braintree::Error) { @pay_customer.charge(2000_00) }
    assert_equal "Do Not Honor", err.message
  end

  test "braintree fails subscribing with invalid cards" do
    # This requires Card Verification to be enabled in the Braintree account
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    err = assert_raises(Pay::Braintree::Error) do
      @pay_customer.subscribe(plan: "do-not-honor")
    end
    assert_equal "Do Not Honor", err.message
    assert_equal Braintree::ErrorResult, err.cause.class
  end

  test "braintree handles invalid parameters" do
    err = assert_raises(Pay::Braintree::AuthorizationError) { @pay_customer.charge(10_00, metadata: {}) }
    assert_equal "Either the data you submitted is malformed and does not match the API or the API key you used may not be authorized to perform this action.", err.message
  end

  test "braintree card is automatically updated on subscribe" do
    assert_nil @pay_customer.data
    @pay_customer.update_payment_method "fake-valid-discover-nonce"
    assert_equal "Discover", @pay_customer.default_payment_method.brand
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    @pay_customer.subscribe
    assert_equal "Visa", @pay_customer.default_payment_method.brand
  end
end
