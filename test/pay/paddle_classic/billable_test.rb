require "test_helper"

class Pay::PaddleClassic::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_classic)
  end

  test "paddle classic can create a charge" do
    charge = @pay_customer.charge(1000, {charge_name: "Test"})
    assert_equal Pay::Charge, charge.class
    assert_equal 1000, charge.amount
  end

  test "paddle classic cannot create a charge without charge_name" do
    assert_raises(Pay::Error) { @pay_customer.charge(1000) }
  end

  test "retrieving a paddle classic subscription" do
    subscription = Pay::PaddleClassic.client.users.list(subscription_id: "3576390").data.try(:first)
    assert_equal @pay_customer.processor_subscription("3576390").subscription_id, subscription.subscription_id
  end

  test "paddle classic can sync payment information" do
    Pay::PaddleClassic::PaymentMethod.sync(pay_customer: @pay_customer)

    assert_equal "card", @pay_customer.default_payment_method.type
    assert_equal "Visa", @pay_customer.default_payment_method.brand
    assert_equal "0020", @pay_customer.default_payment_method.last4
    assert_equal "06", @pay_customer.default_payment_method.exp_month
    assert_equal "2022", @pay_customer.default_payment_method.exp_year
  end

  test "paddle classic can add payment method" do
    assert @pay_customer.add_payment_method
  end

  test "paddle classic can update payment method" do
    assert @pay_customer.update_payment_method(nil)
  end
end
