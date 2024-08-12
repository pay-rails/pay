require "test_helper"

class Pay::PaddleClassic::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_classic)
  end

  test "paddle classic cancel" do
    subscription = @pay_customer.subscription
    next_payment_date = Time.parse(subscription.api_record.next_payment[:date])
    assert_difference "@pay_customer.payment_methods.count", -1 do
      subscription.cancel
    end
    assert_equal subscription.ends_at, next_payment_date
    assert_equal "canceled", subscription.status
    refute subscription.active?
  end

  test "paddle classic cancel with future ends_at" do
    subscription = @pay_customer.subscription
    next_payment_date = Time.parse(subscription.api_record.next_payment[:date])
    travel_to next_payment_date - 1.month
    assert_difference "@pay_customer.payment_methods.count", -1 do
      subscription.cancel
    end
    assert_equal subscription.ends_at, next_payment_date
    assert_equal "active", subscription.status
    assert subscription.active?

    travel_to next_payment_date + 1.day
    refute subscription.active?
  end

  test "paddle classic cancel_now!" do
    subscription = @pay_customer.subscription
    assert_difference "@pay_customer.payment_methods.count", -1 do
      subscription.cancel_now!
    end
    assert subscription.ends_at <= Time.current
    assert_equal "canceled", subscription.status
  end

  test "paddle classic processor subscription" do
    assert_equal @pay_customer.subscription.api_record.class, Paddle::Classic::User
    assert_equal "active", @pay_customer.subscription.status
  end

  test "paddle classic pause" do
    subscription = @pay_customer.subscription
    next_payment_date = Time.zone.parse(subscription.api_record.next_payment[:date])
    subscription.pause
    assert subscription.paused?
    assert_equal next_payment_date, subscription.pause_starts_at
  end

  test "paddle classic pause grace period" do
    @pay_customer.subscription.update!(pause_starts_at: Time.zone.now + 1.week, status: :paused)
    subscription = @pay_customer.subscription
    assert subscription.paused?
    assert subscription.on_grace_period?
  end

  test "paddle classic paused subscription is not active" do
    @pay_customer.subscription.update!(status: :paused)
    refute @pay_customer.subscription.active?
  end

  test "paddle classic paused subscription is paused" do
    @pay_customer.subscription.update!(status: :paused)
    assert @pay_customer.subscription.paused?
  end

  test "paddle classic paused subscription is not canceled" do
    @pay_customer.subscription.update!(status: :paused)
    assert_not @pay_customer.subscription.canceled?
  end

  test "paddle classic resume on paused state" do
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      subscription = @pay_customer.subscription
      subscription.update!(status: :trialing, trial_ends_at: 3.days.from_now)
      subscription.pause
      assert_equal subscription.pause_starts_at.to_date, subscription.api_record.next_payment[:date].to_date

      subscription.resume
      assert_nil subscription.pause_starts_at
      assert_equal "active", subscription.status
    end
  end

  test "paddle classic can swap plans" do
    @pay_customer.subscription.swap("594470")
    assert_equal 594470, @pay_customer.subscription.api_record.plan_id
    assert_equal "active", @pay_customer.subscription.status
  end

  test "paused from timestamp" do
    pay_subscriptions(:paddle_classic).update(pause_starts_at: 14.days.from_now)
    assert_equal ActiveSupport::TimeWithZone, pay_subscriptions(:paddle_classic).pause_starts_at.class
  end

  test "paddle classic cancel paused subscription" do
    subscription = @pay_customer.subscription
    subscription.update(status: :paused, pause_starts_at: "Sat, 04 Jul 2020 00:00:00.000000000 UTC +00:00")
    assert_nil subscription.api_record.next_payment
    assert_difference "@pay_customer.payment_methods.count", -1 do
      subscription.cancel
    end
    assert_not_nil subscription.ends_at
    assert_equal subscription.ends_at, subscription.pause_starts_at
    assert_equal "canceled", subscription.status
  end
end
