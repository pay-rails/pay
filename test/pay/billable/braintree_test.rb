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

  test 'can charge card' do
    VCR.use_cassette('braintree-charge') do
      @billable.card_token = 'fake-valid-visa-nonce'
      result = @billable.charge(2900)
      assert result.success?
      assert_equal 29.00, result.transaction.amount
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
    @billable.subscriptions.expects(:any?).returns(true)
    @billable.email = "mynewemail@example.org"
    @billable.expects(:update_braintree_email!)
    @billable.save
  end
end
