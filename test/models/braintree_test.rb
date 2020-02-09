require "test_helper"

class Pay::Subscription::BraintreeTest < ActiveSupport::TestCase
  setup do
    @billable = User.new email: "test@example.com"
    @billable.processor = "braintree"
    @billable.card_token = "fake-valid-visa-nonce"
  end

  test "braintree cancel" do
    @billable.subscribe(trial_period_days: 0)
    @subscription = @billable.subscription
    @subscription.cancel
    assert_equal @subscription.ends_at.to_date, @subscription.processor_subscription.billing_period_end_date.to_date
    assert_equal "canceled", @subscription.status
  end

  test "braintree cancel_now!" do
    @billable.subscribe(trial_period_days: 0)
    @subscription = @billable.subscription
    @subscription.cancel_now!
    assert @subscription.ends_at <= Time.zone.now
    assert_equal "canceled", @subscription.status
  end

  test "braintree resume on grace period" do
    travel_to(VCR.current_cassette.originally_recorded_at || Time.current) do
      @billable.subscribe(trial_period_days: 14)
      @subscription = @billable.subscription
      @subscription.cancel
      assert_equal @subscription.ends_at, @subscription.trial_ends_at

      @subscription.resume
      assert_nil @subscription.ends_at
      assert_equal "active", @subscription.status
    end
  end

  test "braintree processor subscription" do
    @billable.subscribe(trial_period_days: 0)
    assert_equal @billable.subscription.processor_subscription.class, Braintree::Subscription
    assert_equal "active", @billable.subscription.status
  end

  test "braintree can swap plans" do
    @billable.subscribe(plan: "default", trial_period_days: 0)
    @billable.subscription.swap("big")

    assert_equal "big", @billable.subscription.processor_subscription.plan_id
    assert_equal "active", @billable.subscription.status
  end

  test "braintree can swap plans between frequencies" do
    @billable.subscribe(plan: "default", trial_period_days: 0)
    @billable.subscription.swap("yearly")

    assert_equal "yearly", @billable.subscription.processor_subscription.plan_id
    assert_equal "active", @billable.subscription.status
  end
end
