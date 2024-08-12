require "test_helper"

class Pay::Braintree::SubscriptionTest < ActiveSupport::TestCase
  setup do
    @pay_customer = Pay::Braintree::Customer.create!(processor: :braintree, owner: users(:none))
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
  end

  test "braintree cancel" do
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      @pay_customer.subscribe(trial_period_days: 0)
      @subscription = @pay_customer.subscription
      @subscription.cancel
      assert_equal "active", @subscription.status
      assert @subscription.on_grace_period?
      assert @subscription.active?
      assert_equal @subscription.ends_at.to_date, @subscription.api_record.billing_period_end_date.to_date
    end
  end

  test "braintree cancel_now!" do
    @pay_customer.subscribe(trial_period_days: 0)
    @subscription = @pay_customer.subscription
    @subscription.cancel_now!
    assert_equal "canceled", @subscription.status
    refute @subscription.on_grace_period?
    refute @subscription.active?
    assert_nil @subscription.trial_ends_at
  end

  test "braintree resume on grace period" do
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      @pay_customer.subscribe(trial_period_days: 14)
      @subscription = @pay_customer.subscription
      @subscription.cancel
      assert @subscription.on_trial?
      assert @subscription.on_grace_period?
      @subscription.resume
      assert @subscription.active?
      assert_not @subscription.on_grace_period?
      assert_equal "active", @subscription.status
    end
  end

  test "braintree cancel_now on trial" do
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      @pay_customer.subscribe(trial_period_days: 14)
      pay_subscription = @pay_customer.subscription
      pay_subscription.cancel_now!

      # Account for time hitting the API because we've frozen time and ends_at is ahead
      travel 2.seconds

      # Canceling during a trial ends the subscription, but continues to give access during the trial period
      assert_equal "canceled", pay_subscription.status
      refute pay_subscription.active?
      assert pay_subscription.on_trial?
      assert pay_subscription.ended?
      assert_not_includes @pay_customer.subscriptions.active, pay_subscription
    end
  end

  test "braintree processor subscription" do
    @pay_customer.subscribe(trial_period_days: 0)
    assert_equal @pay_customer.subscription.api_record.class, Braintree::Subscription
    assert_equal "active", @pay_customer.subscription.status
  end

  test "braintree can swap plans" do
    @pay_customer.subscribe(plan: "default", trial_period_days: 0)
    @pay_customer.subscription.swap("big")

    assert_equal "big", @pay_customer.subscription.api_record.plan_id
    assert_equal "active", @pay_customer.subscription.status
  end

  test "braintree can swap plans between frequencies" do
    @pay_customer.subscribe(plan: "default", trial_period_days: 0)
    @pay_customer.subscription.swap("yearly")

    assert_equal "yearly", @pay_customer.subscription.api_record.plan_id
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
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      pay_subscription = @pay_customer.subscribe(plan: "default", trial_period_days: 14)
      processor_id = pay_subscription.processor_id

      # Remove charges and delete record without canceling / callbacks
      pay_subscription.charges.destroy_all
      pay_subscription.delete

      pay_subscription = Pay::Braintree::Subscription.sync(processor_id)
      assert pay_subscription.active?
      assert pay_subscription.on_trial?
    end
  end

  test "braintree sync canceled subscription" do
    pay_subscription = @pay_customer.subscribe(plan: "default", trial_period_days: 0)
    processor_id = pay_subscription.processor_id

    # Remove charges and delete record without canceling / callbacks
    pay_subscription.charges.destroy_all
    pay_subscription.cancel_now!
    pay_subscription.delete

    pay_subscription = Pay::Braintree::Subscription.sync(processor_id)
    assert pay_subscription.canceled?
    refute pay_subscription.on_grace_period?
    refute pay_subscription.active?
  end

  test "braintree sync canceled subscription with trial" do
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      travel 1.minute
      pay_subscription = @pay_customer.subscribe(plan: "default", trial_period_days: 14)
      processor_id = pay_subscription.processor_id

      pay_subscription.cancel_now!
      pay_subscription.delete

      pay_subscription = Pay::Braintree::Subscription.sync(processor_id)

      # Canceling during a trial ends the subscription, but continues to give acess during the trial period
      assert_equal "canceled", pay_subscription.status
      refute pay_subscription.active?
      assert pay_subscription.on_trial?
      assert pay_subscription.ended?
      assert_not_includes @pay_customer.subscriptions.active, pay_subscription
    end
  end
end
