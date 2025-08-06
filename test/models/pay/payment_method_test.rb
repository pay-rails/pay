require "test_helper"

class Pay::PaymentMethodTest < ActiveSupport::TestCase
  test "owner" do
    assert_equal users(:stripe), pay_payment_methods(:one).owner
  end
end
