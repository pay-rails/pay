require "test_helper"

class Pay::LemonSqueezy::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:lemon_squeezy)
  end

  test "lemon squeezy processor subscription" do
    assert_equal @pay_customer.subscription.processor_subscription.class, ::LemonSqueezy::Subscription
    assert_equal "active", @pay_customer.subscription.status
  end

  test "lemon squeezy paused subscription is not active" do
    @pay_customer.subscription.update!(status: :paused)
    refute @pay_customer.subscription.active?
  end

  test "lemon squeezy paused subscription is paused" do
    @pay_customer.subscription.update!(status: :paused)
    assert @pay_customer.subscription.paused?
  end

  test "lemon squeezy paused subscription is not canceled" do
    @pay_customer.subscription.update!(status: :paused)
    assert_not @pay_customer.subscription.canceled?
  end

  test "lemon squeezy can swap plans" do
    @pay_customer.subscription.swap("174873", variant_id: "225676")
    assert_equal 225676, @pay_customer.subscription.processor_subscription.variant_id
    assert_equal "active", @pay_customer.subscription.status
  end
end
