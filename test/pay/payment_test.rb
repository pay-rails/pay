require "test_helper"

class Pay::Payment::Test < ActiveSupport::TestCase
  test "amount_with_currency" do
    fake_payment_intent = OpenStruct.new(amount: 12_34, currency: "usd")
    assert_equal "$12.34", Pay::Payment.new(fake_payment_intent).amount_with_currency
  end
end
