require 'test_helper'
require 'minitest/mock'

class Pay::Braintree::Billable::Test < ActiveSupport::TestCase
  setup do
    @billable = User.new email: "test@example.com"
    @billable.processor = "braintree"
  end

  test 'getting a customer' do
    VCR.use_cassette('braintree-customer') do
      customer = @billable.customer
      assert customer.id.present?
      assert_equal "test@example.com", customer.email
    end
  end

  test 'can store card' do
    VCR.use_cassette('braintree-card') do
      @billable.card_token = 'fake-valid-visa-nonce'
      result = @billable.customer

      assert_equal 'Visa', @billable.card_type
      assert_nil @billable.card_token
    end
  end

  test 'fails with invalid cards' do
    # This requires Card Verification to be enabled in the Braintree account
    VCR.use_cassette('braintree-invalid-card') do
      @billable.card_token = 'fake-processor-declined-visa-nonce'
      err = assert_raises Pay::Error do
        @billable.customer
      end

      assert_equal "Do Not Honor", err.message
    end
  end

  test 'can update card' do
    VCR.use_cassette('braintree-update-card') do
      @billable.customer # Make sure we have a customer object
      @billable.update_card('fake-valid-discover-nonce')
      assert_equal 'Discover', @billable.card_type
      assert_nil @billable.card_token
    end
  end

  test 'can charge card with credit card' do
    VCR.use_cassette('braintree-credit-card-charge') do
      @billable.card_token = 'fake-valid-visa-nonce'
      charge = @billable.charge(29_00)

      # Make sure it saved to the database correctly
      assert_equal 29_00, charge.amount
      assert_equal "Visa", charge.card_type
    end
  end

  test 'can charge card with venmo' do
    VCR.use_cassette('braintree-venmo-charge') do
      @billable.card_token = 'fake-venmo-account-nonce'
      charge = @billable.charge(29_00)

      # Make sure it saved to the database correctly
      assert_equal 29_00, charge.amount
      assert_equal "Venmo", charge.card_type
    end
  end

  # Invalid amount will cause the transaction to fail
  # https://developers.braintreepayments.com/reference/general/testing/ruby#amount-200000-300099
  test 'handles charge failures' do
    VCR.use_cassette('braintree-failed-charge') do
      @billable.card_token = 'fake-valid-visa-nonce'
      charge = @billable.charge(2000_00)
      assert_nil charge
    end
  end

  test 'can create a subscription' do
    VCR.use_cassette('braintree-subscribe') do
      @billable.card_token = 'fake-valid-visa-nonce'
      @billable.subscribe
      assert @billable.subscribed?
    end
  end

  test 'email changed' do
    # Must already have a processor ID
    @billable.update(processor_id: "fake")

    Pay::EmailSyncJob.expects(:perform_later).with(@billable.id)
    @billable.update(email: "mynewemail@example.org")
  end
end
