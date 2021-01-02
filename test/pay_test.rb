require "test_helper"

class Pay::Test < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, Pay
  end

  test "default chargeable class is Charge" do
    assert Pay.chargeable_class, "Pay::Charge"
  end

  test "default chargeable table is charges" do
    assert Pay.chargeable_table, "charges"
  end

  test "default automount_routes is true" do
    assert Pay.automount_routes, true
  end

  test "default routes_path is /pay" do
    assert Pay.routes_path, "/pay"
  end

  test "can set business name" do
    assert Pay.respond_to?(:business_name)
    assert Pay.respond_to?(:business_name=)
  end

  test "can set business address" do
    assert Pay.respond_to?(:business_address)
    assert Pay.respond_to?(:business_address=)
  end

  test "can set application name" do
    assert Pay.respond_to?(:application_name)
    assert Pay.respond_to?(:application_name=)
  end

  test "can set support email" do
    assert Pay.respond_to?(:support_email)
    assert Pay.respond_to?(:support_email=)
  end

  test "can set default product name" do
    assert Pay.respond_to?(:default_product_name)
    assert Pay.respond_to?(:default_product_name=)
  end

  test "can set default plan name" do
    assert Pay.respond_to?(:default_plan_name)
    assert Pay.respond_to?(:default_plan_name=)
  end
end
