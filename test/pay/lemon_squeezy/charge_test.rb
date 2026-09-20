require "test_helper"

class Pay::LemonSqueezy::ChargeTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:lemon_squeezy)
  end

  test "sync dispatches on the processor_id prefix" do
    Pay::LemonSqueezy::Charge.expects(:sync_order).with("1", object: nil)
    Pay::LemonSqueezy::Charge.sync("order:1")

    Pay::LemonSqueezy::Charge.expects(:sync_subscription_invoice).with("2", object: nil)
    Pay::LemonSqueezy::Charge.sync("subscription_invoice:2")
  end

  test "update persists without calling the API" do
    charge = Pay::LemonSqueezy::Charge.create!(customer: @pay_customer, processor_id: "order:1", amount: 10_00)
    ::LemonSqueezy::Order.expects(:retrieve).never

    assert charge.update(amount_refunded: 5_00)
    assert_equal 5_00, charge.reload.amount_refunded
  end
end
