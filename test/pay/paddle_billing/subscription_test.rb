require "test_helper"

class Pay::PaddleBilling::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_billing)
  end

  test "paddle billing processor subscription" do
    assert_equal @pay_customer.subscription.api_record.class, ::Paddle::Subscription
    assert_equal "active", @pay_customer.subscription.status
  end

  test "paddle billing paused subscription is not active" do
    @pay_customer.subscription.update!(status: :paused)
    refute @pay_customer.subscription.active?
  end

  test "paddle billing paused subscription is paused" do
    @pay_customer.subscription.update!(status: :paused)
    assert @pay_customer.subscription.paused?
  end

  test "paddle billing paused subscription is not canceled" do
    @pay_customer.subscription.update!(status: :paused)
    assert_not @pay_customer.subscription.canceled?
  end

  test "paddle billing can swap plans" do
    @pay_customer.subscription.swap("pri_01h7qfsc8apejhjgqqx50rghdz")
    assert_equal "pri_01h7qfsc8apejhjgqqx50rghdz", @pay_customer.subscription.api_record.items.first.price.id
    assert_equal "active", @pay_customer.subscription.status
  end
end
