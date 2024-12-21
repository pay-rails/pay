require "test_helper"

class Pay::AwsMarketplace::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:aws_marketplace)
    @subscription = pay_subscriptions(:aws_marketplace)
  end

  test "aws processor subscription" do
    assert_equal @subscription, @subscription.api_record
  end

  test "aws processor cancel" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.cancel
    end
  end

  test "aws processor trial period" do
    refute @subscription.on_trial?
  end

  test "aws processor cancel_now!" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.cancel_now!
    end
  end

  test "aws processor on_grace_period?" do
    freeze_time do
      @subscription.update(ends_at: 1.week.from_now)
      assert @subscription.on_grace_period?
    end
  end

  test "aws processor resume" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.resume
    end
  end

  test "aws processor swap" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.swap("another_plan")
    end
  end

  test "aws change quantity" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.change_quantity(3)
    end
  end

  test "aws cancel_now! on trial" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.cancel_now!
    end
  end

  test "aws nonresumable subscription" do
    @subscription.update(ends_at: 1.week.from_now)
    @subscription.reload
    assert @subscription.on_grace_period?
    assert @subscription.canceled?
    refute @subscription.resumable?
  end
end
