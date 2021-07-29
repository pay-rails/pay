require "test_helper"

class Pay::MerchantTest < ActiveSupport::TestCase
  test "has multiple pay merchants" do
    assert accounts(:one).pay_merchants.count > 1
  end

  test "has default pay merchant" do
    assert_equal pay_merchants(:default), accounts(:one).merchant
  end

  test "cannot have multiple default pay merchants" do
    refute pay_merchants(:other).update(default: true)
  end

  test "can create pay merchants" do
    assert_difference "Pay::Merchant.count", 2 do
      accounts(:two).set_merchant_processor :stripe
      accounts(:two).set_merchant_processor :braintree
    end
  end

  test "doesn't change pay merchant if already default" do
    assert_no_difference "Pay::Merchant.count" do
      accounts(:one).set_merchant_processor :stripe
    end
  end
end
