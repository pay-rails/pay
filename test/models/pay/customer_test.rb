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

  test "update_customer!" do
    assert pay_customers(:fake).respond_to?(:update_customer!)
  end
end
