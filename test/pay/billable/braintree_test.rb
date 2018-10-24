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
    customer = @billable.customer
    assert customer.id.present?
    assert_equal "test@example.com", customer.email
  end

  test 'can store card' do
    @billable.card_token = 'fake-valid-visa-nonce'
    result = @billable.customer

    assert_equal 'Visa', @billable.card_brand
  end

  test 'fails with invalid cards' do
    @billable.card_token = 'fake-processor-declined-visa-nonce'
    err = assert_raises Pay::Error do
      @billable.customer
    end

    assert_equal "Do Not Honor", err.result.message
  end
end
