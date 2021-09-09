require "test_helper"

class Pay::PaymentMethodTest < ActiveSupport::TestCase
  test "text data column" do
    pay_payment_methods(:one).update!(stripe_account: "acct_1")
    assert_equal "acct_1", pay_payment_methods(:one).stripe_account
  end
end
