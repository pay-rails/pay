require "test_helper"
require "minitest/mock"

class Pay::Braintree::CustomerTest < ActiveSupport::TestCase
  setup do
    @pay_customer = Pay::Braintree::Customer.create!(processor: :braintree, owner: users(:none))
  end

  test "braintree customer" do
    braintree_customer = @pay_customer.api_record
    assert braintree_customer.id.present?
    assert_equal "braintree@example.org", braintree_customer.email
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

  # Disable because you have to enable Apple Pay in Braintree
  # test "braintree can charge card with Apple Pay Card" do
  #  @pay_customer.update_payment_method "fake-apple-pay-visa-nonce"
  #  charge = @pay_customer.charge(29_00)
  #  assert_equal "card", charge.payment_method_type
  #  assert_equal "Apple Pay - Visa", charge.brand
  # end

  test "braintree can charge card with Google Pay Card" do
    # If Braintree ever introduces fake google pay nonces, we can update this
    @pay_customer.update_payment_method "fake-android-pay-visa-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "card", charge.payment_method_type
    assert_equal "Visa", charge.brand
  end

  test "braintree can charge card with Samsung Pay Card" do
    @pay_customer.update_payment_method "tokensam_fake_mastercard"
    charge = @pay_customer.charge(29_00)
    assert_equal "card", charge.payment_method_type
    assert_equal "MasterCard", charge.brand
  end

  test "braintree can charge card with Visa Checkout Card" do
    @pay_customer.update_payment_method "fake-visa-checkout-amex-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "card", charge.payment_method_type
    assert_equal "American Express", charge.brand
  end

  # test "braintree can charge card with PayPal Account" do
  #   @pay_customer.update_payment_method "fake-paypal-billing-agreement-nonce"
  #   charge = @pay_customer.charge(29_00)
  #   assert_equal "paypal", charge.payment_method_type
  #   assert_equal "PayPal", charge.brand
  # end

  test "braintree can charge card with Venmo" do
    @pay_customer.update_payment_method "fake-venmo-account-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "venmo", charge.payment_method_type
    assert_equal "Venmo", charge.brand
  end

  test "braintree update credit card" do
    @pay_customer.update_payment_method "fake-valid-discover-nonce"
    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "Discover", @pay_customer.default_payment_method.brand
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

  test "braintree update Samsung Pay Card" do
    @pay_customer.update_payment_method "tokensam_fake_mastercard"
    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "MasterCard", @pay_customer.default_payment_method.brand
  end

  test "braintree update Visa Checkout Card" do
    @pay_customer.update_payment_method "fake-visa-checkout-amex-nonce"
    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "American Express", @pay_customer.default_payment_method.brand
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

  # Invalid amount will cause the transaction to fail
  # https://developers.braintreepayments.com/reference/general/testing/ruby#amount-200000-300099
  test "braintree handles charge failures" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    assert_raises(Pay::Braintree::Error) { @pay_customer.charge(2000_00) }
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
    Pay::CustomerSyncJob.expects(:perform_later).with(@pay_customer.id)
    @pay_customer.owner.update(email: "mynewemail@example.org")
  end

  test "braintree trial period options" do
    travel_to(VCR.current_cassette.originally_recorded_at || Time.current) do
      @pay_customer.update_payment_method "fake-valid-visa-nonce"
      subscription = @pay_customer.subscribe(trial_period_days: 15)
      # Braintree subscriptions don't use trialing status for simplicity
      assert_equal "active", subscription.status
      assert_not_nil subscription.trial_ends_at
      # Time.zone may not match the timezone in your Braintree account, so we'll be lenient on this assertion
      assert subscription.trial_ends_at > 14.days.from_now
    end
  end

  # $2000.00 - 2999.99 returns a Processor Declined
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
