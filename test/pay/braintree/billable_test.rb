require "test_helper"
require "minitest/mock"

class Pay::Braintree::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:braintree)
    @pay_customer.update(processor_id: nil)
    @pay_customer.subscriptions.delete_all
  end

  test "braintree customer" do
    customer = @pay_customer.customer
    assert customer.id.present?
    assert_equal "braintree@example.org", customer.email
  end

  test "braintree can store card" do
    @pay_customer.payment_method_token = "fake-valid-visa-nonce"
    @pay_customer.customer

    assert_equal "Visa", @pay_customer.data["type"]
    assert_nil @pay_customer.payment_method_token
  end

  test "braintree fails with invalid cards" do
    # This requires Card Verification to be enabled in the Braintree account
    @pay_customer.payment_method_token = "fake-processor-declined-visa-nonce"
    err = assert_raises(Pay::Braintree::Error) { @pay_customer.customer }
    assert_equal "Do Not Honor", err.message
  end

  test "braintree can update card" do
    @pay_customer.update_payment_method "fake-valid-discover-nonce"
    assert_equal "Discover", @pay_customer.data["type"]
    assert_nil @pay_customer.payment_method_token
  end

  test "braintree can charge card with credit card" do
    @pay_customer.payment_method_token = "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)

    # Make sure it saved to the database correctly
    assert_equal 29_00, charge.amount
    assert_equal "Visa", charge.card_type
  end

  test "braintree can charge card with venmo" do
    @pay_customer.payment_method_token = "fake-venmo-account-nonce"
    charge = @pay_customer.charge(29_00)

    # Make sure it saved to the database correctly
    assert_equal 29_00, charge.amount
    assert_equal "Venmo", charge.card_type
  end

  # Invalid amount will cause the transaction to fail
  # https://developers.braintreepayments.com/reference/general/testing/ruby#amount-200000-300099
  test "braintree handles charge failures" do
    @pay_customer.payment_method_token = "fake-valid-visa-nonce"
    @pay_customer.customer
    assert_raises(Pay::Braintree::Error) { @pay_customer.charge(2000_00) }
  end

  test "braintree fails with paypal processor declined" do
    @pay_customer.payment_method_token = "fake-paypal-billing-agreement-nonce	"
    @pay_customer.customer
    assert_raises(Pay::Braintree::Error) { @pay_customer.charge(5001_01) }
  end

  test "braintree can create a subscription" do
    @pay_customer.payment_method_token = "fake-valid-visa-nonce"
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
      @pay_customer.payment_method_token = "fake-valid-visa-nonce"
      subscription = @pay_customer.subscribe(trial_period_days: 15)
      # Braintree subscriptions don't use trialing status for simplicity
      assert_equal "active", subscription.status
      assert_not_nil subscription.trial_ends_at
      # Time.zone may not match the timezone in your Braintree account, so we'll be lenient on this assertion
      assert subscription.trial_ends_at > 14.days.from_now
    end
  end

  test "braintree fails charges with invalid cards" do
    # This requires Card Verification to be enabled in the Braintree account
    @pay_customer.payment_method_token = "fake-processor-declined-visa-nonce"
    err = assert_raises(Pay::Braintree::Error) { @pay_customer.charge(10_00) }
    assert_equal "Do Not Honor", err.message
  end

  test "braintree fails subscribing with invalid cards" do
    # This requires Card Verification to be enabled in the Braintree account
    @pay_customer.payment_method_token = "fake-processor-declined-visa-nonce"
    err = assert_raises(Pay::Braintree::Error) { @pay_customer.subscribe }
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
    assert_equal "Discover", @pay_customer.data["type"]
    @pay_customer.payment_method_token = "fake-valid-visa-nonce"
    @pay_customer.subscribe
    assert_equal "Visa", @pay_customer.data["type"]
  end
end
