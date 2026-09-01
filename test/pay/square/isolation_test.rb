require "test_helper"

# Cross-merchant isolation: one owner + two square_accounts must yield two distinct
# Pay::Customers (mirrors the Stripe Connect fix in #1198).
class Pay::Square::IsolationTest < Pay::Square::TestCase
  setup do
    @user = users(:none)
  end

  test "same owner with two square_accounts gets two isolated pay_customers" do
    c1 = @user.add_payment_processor(:square, square_account: "MERCHANT_1")
    c2 = @user.add_payment_processor(:square, square_account: "MERCHANT_2")

    assert_not_equal c1.id, c2.id
    assert_equal "MERCHANT_1", c1.square_account
    assert_equal "MERCHANT_2", c2.square_account
    assert_equal 2, @user.pay_customers.where(processor: "square").count
  end

  test "same owner + same square_account reuses the pay_customer" do
    c1 = @user.add_payment_processor(:square, square_account: "MERCHANT_1")
    c2 = @user.add_payment_processor(:square, square_account: "MERCHANT_1")

    assert_equal c1.id, c2.id
    assert_equal 1, @user.pay_customers.where(processor: "square").count
  end
end
