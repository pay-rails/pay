require 'test_helper'
require 'minitest/mock'

class Pay::Billable::Braintree::Test < ActiveSupport::TestCase
  setup do
    Pay.braintree_gateway = Braintree::Gateway.new(
      environment: :sandbox,
      merchant_id: "zyfwpztymjqdcc5g",
      public_key:  "5r59rrxhn89npc9n",
      private_key: "00f0df79303e1270881e5feda7788927",
    )

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

      assert_equal 'Visa', @billable.card_brand
    end
  end

  test 'fails with invalid cards' do
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
      assert_equal 'Discover', @billable.card_brand
    end
  end

  test 'can charge card with credit card' do
    VCR.use_cassette('braintree-credit-card-charge') do
      @billable.card_token = 'fake-valid-visa-nonce'
      result = @billable.charge(29_00)
      assert result.success?
      assert_equal 29.00, result.transaction.amount

      # Make sure it saved to the database correctly
      assert_equal result.transaction.id, @billable.charges.last.processor_id
      assert_equal 29_00, @billable.charges.last.amount
      assert_equal "Visa", @billable.charges.last.card_type
    end
  end

  test 'can charge card with venmo' do
    VCR.use_cassette('braintree-venmo-charge') do
      @billable.card_token = 'fake-venmo-account-nonce'
      result = @billable.charge(29_00)
      assert result.success?

      # Make sure it saved to the database correctly
      assert_equal result.transaction.id, @billable.charges.last.processor_id
      assert_equal "Venmo", @billable.charges.last.card_type
    end
  end

  # Invalid amount will cause the transaction to fail
  # https://developers.braintreepayments.com/reference/general/testing/ruby#amount-200000-300099
  test 'handles charge failures' do
    VCR.use_cassette('braintree-failed-charge') do
      @billable.card_token = 'fake-valid-visa-nonce'
      result = @billable.charge(2000_00)
      assert !result.success?
    end
  end

  test 'can create a subscription' do
    VCR.use_cassette('braintree-subscribe') do
      @billable.card_token = 'fake-valid-visa-nonce'
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
