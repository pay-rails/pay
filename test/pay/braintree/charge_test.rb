require "test_helper"
require "minitest/mock"

class Pay::Braintree::Charge::Test < ActiveSupport::TestCase
  setup do
    @billable = User.new email: "test@example.com"
    @billable.processor = "braintree"
  end

  test "can partially refund a transaction" do
    @billable.card_token = "fake-valid-visa-nonce"

    charge = @billable.charge(29_00)
    assert charge.present?

    charge.refund!(10_00)
    assert_equal 10_00, charge.amount_refunded
  end

  test "can fully refund a transaction" do
    @billable.card_token = "fake-valid-visa-nonce"

    charge = @billable.charge(37_00)
    assert charge.present?

    charge.refund!
    assert_equal 37_00, charge.amount_refunded
  end

  test "you can ask the charge for the type" do
    assert Pay::Charge.new(processor: "stripe").stripe?
    assert Pay::Charge.new(processor: "braintree").braintree?
    assert Pay::Charge.new(processor: "braintree", card_type: "PayPal").paypal?
  end
end
