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

  test "update_api_record" do
    assert pay_customers(:fake).respond_to?(:update_api_record)
  end

  test "update_api_record with a promotion code" do
    pay_customer = pay_customers(:fake)
    assert pay_customer.update_api_record(promotion_code: "promo_xxx123")
  end

  test "not_fake scope" do
    assert_not_includes Pay::Customer.not_fake_processor, pay_customers(:fake)
    assert_includes Pay::Customer.not_fake_processor, pay_customers(:stripe)
  end
end
