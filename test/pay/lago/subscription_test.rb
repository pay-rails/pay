require "test_helper"

class Pay::Lago::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:lago)
    @subscription = @pay_customer.subscribe
  end

  test "lago processor subscription" do
    assert_equal @subscription.processor_id, @subscription.processor_subscription.external_id
  end

  test "lago processor cancel" do
    freeze_time do
      @subscription.cancel
      @subscription.reload
      assert_equal @subscription.cancelled?, true
    end
  end

  test "lago processor on_grace_period? is always false" do
    assert_equal @subscription.on_grace_period?, false
  end

  test "lago processor paused? is always false" do
    assert_equal @subscription.paused?, false
  end

  test "lago processor resume raises an error" do
    assert_raises(Pay::Lago::Error, "Lago subscriptions cannot be paused.") { @subscription.resume }
  end

  test "lago processor pause raises an error" do
    assert_raises(Pay::Lago::Error, "Lago subscriptions cannot be paused.") { @subscription.pause }
  end

  test "lago processor swap" do
    @subscription.swap("another_plan")
    assert_equal @subscription.changing_plan?, true
    assert_equal @subscription.subscription.next_plan_code, "another_plan"
  end

  test "lago cannot change quantity" do
    assert_raises(Pay::Lago::Error, "Lago subscriptions do not implement quantity.") { @subscription.change_quantity(3) }
  end
end
