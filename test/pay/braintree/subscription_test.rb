require "test_helper"

class Pay::Braintree::SubscriptionTest < ActiveSupport::TestCase
  setup do
    @pay_customer = Pay::Customer.create!(processor: :braintree, owner: users(:none))
    @pay_customer.payment_method_token = "fake-valid-visa-nonce"
  end

  test "braintree cancel" do
    @pay_customer.subscribe(trial_period_days: 0)
    @subscription = @pay_customer.subscription
    @subscription.cancel
    assert_equal @subscription.ends_at.to_date, @subscription.processor_subscription.billing_period_end_date.to_date
    assert_equal "canceled", @subscription.status
  end

  test "braintree cancel_now!" do
    @pay_customer.subscribe(trial_period_days: 0)
    @subscription = @pay_customer.subscription
    @subscription.cancel_now!
    assert @subscription.ends_at <= Time.current
    assert_equal "canceled", @subscription.status
    assert_nil @subscription.trial_ends_at
  end

  test "braintree resume on grace period" do
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      @pay_customer.subscribe(trial_period_days: 14)
      @subscription = @pay_customer.subscription
      @subscription.cancel
      assert_equal @subscription.ends_at, @subscription.trial_ends_at

      @subscription.resume
      assert_nil @subscription.ends_at
      assert_equal "active", @subscription.status
    end
  end

  test "braintree cancel_now! on trial" do
    @pay_customer.subscribe(trial_period_days: 14)
    @subscription = @pay_customer.subscription
    @subscription.cancel_now!
    assert @subscription.ends_at <= Time.current
    assert_equal "canceled", @subscription.status
    assert_equal @subscription.ends_at, @subscription.trial_ends_at
  end

  test "braintree processor subscription" do
    @pay_customer.subscribe(trial_period_days: 0)
    assert_equal @pay_customer.subscription.processor_subscription.class, Braintree::Subscription
    assert_equal "active", @pay_customer.subscription.status
  end

  test "braintree can swap plans" do
    @pay_customer.subscribe(plan: "default", trial_period_days: 0)
    @pay_customer.subscription.swap("big")

    assert_equal "big", @pay_customer.subscription.processor_subscription.plan_id
    assert_equal "active", @pay_customer.subscription.status
  end

  test "braintree can swap plans between frequencies" do
    @pay_customer.subscribe(plan: "default", trial_period_days: 0)
    @pay_customer.subscription.swap("yearly")

    assert_equal "yearly", @pay_customer.subscription.processor_subscription.plan_id
    assert_equal "active", @pay_customer.subscription.status
  end

  test "braintree sync active subscription" do
    pay_subscription = @pay_customer.subscribe(plan: "default", trial_period_days: 0)
    processor_id = pay_subscription.processor_id

    # Remove charges and delete record without canceling / callbacks
    pay_subscription.charges.destroy_all
    pay_subscription.delete

    pay_subscription = Pay::Braintree::Subscription.sync(processor_id)
    assert pay_subscription.active?
  end

  test "braintree sync subscription with trial" do
    pay_subscription = @pay_customer.subscribe(plan: "default", trial_period_days: 14)
    processor_id = pay_subscription.processor_id

    # Remove charges and delete record without canceling / callbacks
    pay_subscription.charges.destroy_all
    pay_subscription.delete

    pay_subscription = Pay::Braintree::Subscription.sync(processor_id)
    assert pay_subscription.active?
    assert pay_subscription.on_trial?
  end

  test "braintree sync canceled subscription" do
    pay_subscription = @pay_customer.subscribe(plan: "default", trial_period_days: 0)
    processor_id = pay_subscription.processor_id

    # Remove charges and delete record without canceling / callbacks
    pay_subscription.charges.destroy_all
    pay_subscription.cancel_now!
    pay_subscription.delete

    pay_subscription = Pay::Braintree::Subscription.sync(processor_id)
    refute pay_subscription.active?
  end

  test "braintree sync canceled subscription with trial" do
    pay_subscription = @pay_customer.subscribe(plan: "default", trial_period_days: 14)
    processor_id = pay_subscription.processor_id

    pay_subscription.cancel_now!
    pay_subscription.delete

    pay_subscription = Pay::Braintree::Subscription.sync(processor_id)
    refute pay_subscription.active?
    assert_not_nil pay_subscription.trial_ends_at
  end
end
