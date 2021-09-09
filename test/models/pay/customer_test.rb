require "test_helper"

class Pay::CustomerTest < ActiveSupport::TestCase
  test "active customers" do
    results = Pay::Customer.active
    assert_includes results, pay_customers(:stripe)
    refute_includes results, pay_customers(:deleted)
  end

  test "deleted customers" do
    assert_includes Pay::Customer.deleted, pay_customers(:deleted)
  end

  test "active?" do
    assert pay_customers(:stripe).active?
  end

  test "deleted?" do
    assert pay_customers(:deleted).deleted?
  end

  test "text data column" do
    pay_customers(:stripe).update!(stripe_account: "acct_1")
    assert_equal "acct_1", pay_customers(:stripe).stripe_account
  end
end
