require "test_helper"

class Pay::Paddle::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle)
  end

  test "paddle cancel" do
    subscription = @pay_customer.subscription
    next_payment_date = Time.zone.parse(subscription.processor_subscription.next_payment[:date])
    assert_difference "@pay_customer.payment_methods.count", -1 do
      subscription.cancel
    end
    assert_equal subscription.ends_at, next_payment_date
    assert_equal "canceled", subscription.status
  end

  test "paddle cancel_now!" do
    subscription = @pay_customer.subscription
    assert_difference "@pay_customer.payment_methods.count", -1 do
      subscription.cancel_now!
    end
    assert subscription.ends_at <= Time.current
    assert_equal "canceled", subscription.status
  end

  test "paddle processor subscription" do
    assert_equal @pay_customer.subscription.processor_subscription.class, OpenStruct
    assert_equal "active", @pay_customer.subscription.status
  end

  test "paddle pause" do
    subscription = @pay_customer.subscription
    next_payment_date = Time.zone.parse(subscription.processor_subscription.next_payment[:date])
    subscription.pause
    assert subscription.paused?
    assert_equal next_payment_date, subscription.paddle_paused_from
  end

  test "paddle pause grace period" do
    @pay_customer.subscription.update!(paddle_paused_from: Time.zone.now + 1.week, status: :paused)
    subscription = @pay_customer.subscription
    assert subscription.paused?
    assert subscription.on_grace_period?
  end

  test "paddle paused subscription is not active" do
    @pay_customer.subscription.update!(status: :paused)
    assert_not @pay_customer.subscription.active?
  end

  test "paddle paused subscription is not canceled" do
    @pay_customer.subscription.update!(status: :paused)
    assert_not @pay_customer.subscription.canceled?
  end

  test "paddle resume on paused state" do
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      subscription = @pay_customer.subscription
      subscription.update!(status: :trialing, trial_ends_at: 3.days.from_now)
      subscription.pause
      assert_equal subscription.paddle_paused_from.to_date, subscription.processor_subscription.next_payment[:date].to_date

      subscription.resume
      assert_nil subscription.paddle_paused_from
      assert_equal "active", subscription.status
    end
  end

  test "paddle can swap plans" do
    @pay_customer.subscription.swap("594470")
    assert_equal 594470, @pay_customer.subscription.processor_subscription.plan_id
    assert_equal "active", @pay_customer.subscription.status
  end

  test "paused from timestamp" do
    pay_subscriptions(:paddle).update(paddle_paused_from: 14.days.from_now)
    assert_equal ActiveSupport::TimeWithZone, pay_subscriptions(:paddle).paddle_paused_from.class
  end

  test "paddle cancel paused subscription" do
    subscription = @pay_customer.subscription
    subscription.update(paddle_paused_from: "Sat, 04 Jul 2020 00:00:00.000000000 UTC +00:00")
    assert_nil subscription.processor_subscription.next_payment
    assert_difference "@pay_customer.payment_methods.count", -1 do
      subscription.cancel
    end
    assert_not_nil subscription.ends_at
    assert_equal subscription.ends_at, subscription.paddle_paused_from
    assert_equal "canceled", subscription.status
  end
end
