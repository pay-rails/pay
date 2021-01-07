require "test_helper"
require "minitest/mock"

class Pay::Braintree::Billable::Test < ActiveSupport::TestCase
  setup do
    @billable = User.new email: "test@example.com"
    @billable.processor = "braintree"
  end

  test "getting a customer" do
    customer = @billable.customer
    assert customer.id.present?
    assert_equal "test@example.com", customer.email
  end

  test "can store card" do
    @billable.card_token = "fake-valid-visa-nonce"
    @billable.customer

    assert_equal "Visa", @billable.card_type
    assert_nil @billable.card_token
  end

  test "fails with invalid cards" do
    # This requires Card Verification to be enabled in the Braintree account
    @billable.card_token = "fake-processor-declined-visa-nonce"
    err = assert_raises(Pay::Braintree::Error) { @billable.customer }
    assert_equal "Do Not Honor", err.message
  end

  test "can update card" do
    @billable.customer # Make sure we have a customer object
    @billable.update_card("fake-valid-discover-nonce")
    assert_equal "Discover", @billable.card_type
    assert_nil @billable.card_token
  end

  test "can charge card with credit card" do
    @billable.card_token = "fake-valid-visa-nonce"
    charge = @billable.charge(29_00)

    # Make sure it saved to the database correctly
    assert_equal 29_00, charge.amount
    assert_equal "Visa", charge.card_type
  end

  test "can charge card with venmo" do
    @billable.card_token = "fake-venmo-account-nonce"
    charge = @billable.charge(29_00)

    # Make sure it saved to the database correctly
    assert_equal 29_00, charge.amount
    assert_equal "Venmo", charge.card_type
  end

  # Invalid amount will cause the transaction to fail
  # https://developers.braintreepayments.com/reference/general/testing/ruby#amount-200000-300099
  test "handles charge failures" do
    @billable.card_token = "fake-valid-visa-nonce"
    @billable.customer
    assert_raises(Pay::Braintree::Error) { @billable.charge(2000_00) }
  end

  test "fails with paypal processor declined" do
    @billable.card_token = "fake-paypal-billing-agreement-nonce	"
    @billable.customer
    assert_raises(Pay::Braintree::Error) { @billable.charge(5001_01) }
  end

  test "can create a braintree subscription" do
    @billable.card_token = "fake-valid-visa-nonce"
    @billable.subscribe
    assert @billable.subscribed?
  end

  test "email changed" do
    # Must already have a processor ID
    @billable.update(processor_id: "fake")

    Pay::EmailSyncJob.expects(:perform_later).with(@billable.id, @billable.class.name)
    @billable.update(email: "mynewemail@example.org")
  end

  test "braintree trial period options" do
    travel_to(VCR.current_cassette.originally_recorded_at || Time.current) do
      @billable.card_token = "fake-valid-visa-nonce"
      subscription = @billable.subscribe(trial_period_days: 15)
      # Braintree subscriptions don't use trialing status for simplicity
      assert_equal "active", subscription.status
      assert_not_nil subscription.trial_ends_at
      # Time.zone may not match the timezone in your Braintree account, so we'll be lenient on this assertion
      assert subscription.trial_ends_at > 14.days.from_now
    end
  end

  test "fails charges with invalid cards" do
    # This requires Card Verification to be enabled in the Braintree account
    @billable.card_token = "fake-processor-declined-visa-nonce"
    err = assert_raises(Pay::Braintree::Error) { @billable.charge(10_00) }
    assert_equal "Do Not Honor", err.message
  end

  test "fails subscribing with invalid cards" do
    # This requires Card Verification to be enabled in the Braintree account
    @billable.card_token = "fake-processor-declined-visa-nonce"
    err = assert_raises(Pay::Braintree::Error) { @billable.subscribe }
    assert_equal "Do Not Honor", err.message
  end

  test "handles invalid parameters" do
    err = assert_raises(Pay::Braintree::AuthorizationError) { @billable.charge(10_00, metadata: {}) }
    assert_equal "Either the data you submitted is malformed and does not match the API or the API key you used may not be authorized to perform this action.", err.message
  end
end
