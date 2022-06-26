require "test_helper"

class Pay::Subscription::Test < ActiveSupport::TestCase
  setup do
    @owner = users(:fake)
    @pay_customer = @owner.payment_processor
    @subscription = @pay_customer.subscriptions.first
  end

  test "validates subscription uniqueness by processor and processor ID" do
    create_subscription(name: "default", processor_id: 1)
    assert_raises ActiveRecord::RecordInvalid do
      create_subscription(name: "default", processor_id: 1)
    end
  end

  test "pay subscription stores metadata" do
    pay_subscription = pay_subscriptions(:stripe)
    metadata = {"foo" => "bar"}
    pay_subscription.update(metadata: metadata)
    assert_equal metadata, pay_subscription.metadata
  end

  test "subscription has many charges" do
    assert_equal pay_charges(:stripe), pay_subscriptions(:stripe).charges.first
  end

  test "braintree?" do
    assert pay_subscriptions(:braintree).braintree?
    refute pay_subscriptions(:fake).braintree?
  end

  test "stripe?" do
    assert pay_subscriptions(:stripe).stripe?
    refute pay_subscriptions(:fake).stripe?
  end

  test "paddle?" do
    assert pay_subscriptions(:paddle).paddle?
    refute pay_subscriptions(:fake).paddle?
  end

  test "fake_processor?" do
    assert pay_subscriptions(:fake).fake_processor?
    refute pay_subscriptions(:stripe).fake_processor?
  end

  test "braintree scope" do
    assert Pay::Subscription.braintree.is_a?(ActiveRecord::Relation)
  end

  test "stripe scope" do
    assert Pay::Subscription.stripe.is_a?(ActiveRecord::Relation)
  end

  test "paddle scope" do
    assert Pay::Subscription.paddle.is_a?(ActiveRecord::Relation)
  end

  test "fake processor scope" do
    assert Pay::Subscription.fake_processor.is_a?(ActiveRecord::Relation)
  end

  test ".for_name(name) scope" do
    subscription1 = create_subscription(name: "default")
    subscription2 = create_subscription(name: "superior")

    subscriptions = Pay::Subscription.for_name("default")
    assert_includes subscriptions, subscription1
    refute_includes subscriptions, subscription2
  end

  test "on trial scope" do
    subscription1 = create_subscription(trial_ends_at: 7.days.from_now)
    subscription2 = create_subscription(trial_ends_at: nil)
    subscription3 = create_subscription(trial_ends_at: 7.days.ago)

    subscriptions = Pay::Subscription.on_trial

    assert_includes subscriptions, subscription1
    refute_includes subscriptions, subscription2
    refute_includes subscriptions, subscription3
  end

  test "cancelled scope" do
    subscription1 = create_subscription(ends_at: 7.days.ago)
    subscription2 = create_subscription(ends_at: 7.days.from_now)
    subscription3 = create_subscription(ends_at: nil)

    subscriptions = Pay::Subscription.cancelled

    assert_includes subscriptions, subscription1
    assert_includes subscriptions, subscription2
    refute_includes subscriptions, subscription3
  end

  test "on grace period scope" do
    subscription1 = create_subscription(ends_at: 7.days.from_now)
    subscription2 = create_subscription(ends_at: nil)
    subscription3 = create_subscription(ends_at: 7.days.ago)

    subscriptions = Pay::Subscription.on_grace_period

    assert_includes subscriptions, subscription1
    refute_includes subscriptions, subscription2
    refute_includes subscriptions, subscription3
  end

  test "active scope" do
    subscription1 = create_subscription
    subscription2 = create_subscription(trial_ends_at: 7.days.from_now)
    subscription3 = create_subscription(ends_at: 7.days.from_now)
    subscription4 = create_subscription(ends_at: 7.days.ago)
    subscription5 = create_subscription(ends_at: 8.days.ago, trial_ends_at: 7.days.ago)

    subscriptions = Pay::Subscription.active

    assert_includes subscriptions, subscription1
    assert_includes subscriptions, subscription2
    assert_includes subscriptions, subscription3
    refute_includes subscriptions, subscription4
    refute_includes subscriptions, subscription5
  end

  test "with_active_customer scope" do
    subscription = create_subscription

    assert_includes Pay::Subscription.with_active_customer, subscription

    @pay_customer.update!(deleted_at: Time.now)

    refute_includes Pay::Subscription.with_active_customer, subscription
  end

  test "with_deleted_customer scope" do
    subscription = create_subscription

    refute_includes Pay::Subscription.with_deleted_customer, subscription

    @pay_customer.update!(deleted_at: Time.now)

    assert_includes Pay::Subscription.with_deleted_customer, subscription
  end

  test "active trial" do
    @subscription.trial_ends_at = 5.minutes.from_now
    assert @subscription.on_trial?
  end

  test "inactive trial" do
    @subscription.trial_ends_at = 5.minutes.ago
    refute @subscription.on_trial?
  end

  test "no trial" do
    @subscription.trial_ends_at = nil
    refute @subscription.on_trial?
  end

  test "cancelled" do
    @subscription.ends_at = 1.week.ago
    assert @subscription.cancelled?
  end

  test "not cancelled" do
    @subscription.ends_at = nil
    refute @subscription.cancelled?
  end

  test "on grace period" do
    @subscription.ends_at = 5.minutes.from_now
    assert @subscription.on_grace_period?
  end

  test "off grace period" do
    @subscription.ends_at = 5.minutes.ago
    refute @subscription.on_grace_period?
  end

  test "no grace period" do
    @subscription.ends_at = nil
    refute @subscription.on_grace_period?
  end

  test "active" do
    @subscription.ends_at = nil
    @subscription.trial_ends_at = nil
    assert @subscription.active?
  end

  test "inactive" do
    @subscription.ends_at = 5.minutes.ago
    @subscription.trial_ends_at = nil
    refute @subscription.active?
  end

  test "cancel" do
    @subscription.cancel
    assert @subscription.ends_at?
  end

  test "cancel trialing" do
    @subscription.update(trial_ends_at: 14.days.from_now)
    @subscription.cancel
    assert_equal @subscription.ends_at.to_date, 14.days.from_now.to_date
  end

  test "cancel_now!" do
    freeze_time do
      @subscription.cancel_now!
      assert @subscription.ends_at <= Time.current
    end
  end

  test "resume on grace period" do
    @subscription.cancel
    @subscription.resume
    refute @subscription.ends_at?
  end

  test "resume off grace period" do
    @subscription.update ends_at: 1.day.ago
    assert_raises StandardError do
      subscription.resume
    end
  end

  test "processor subscription" do
    @subscription.payment_processor.stubs(:subscription).returns(:result)
    assert_equal :result, @subscription.processor_subscription
  end

  test "can swap plans" do
    @subscription.swap("small-annual")
    assert_equal "small-annual", @subscription.processor_plan
  end

  test "statuses affect active state" do
    %w[trialing active].each do |state|
      @subscription.status = state
      assert @subscription.active?
    end

    %w[incomplete incomplete_expired past_due canceled unpaid paused].each do |state|
      @subscription.status = state
      assert_not @subscription.active?
    end
  end

  test "correctly handles v1 subscriptions without statuses" do
    # Subscriptions in Pay v1.x didn't have a status column, so we've set all their statuses to active
    # We just want to make sure those old, ended subscriptions are still correct
    assert_not Pay::Subscription.new(customer: pay_customers(:fake), status: :active, ends_at: 1.day.ago).active?
    assert Pay::Subscription.new(customer: pay_customers(:fake), status: :active, ends_at: 1.day.ago).canceled?
  end

  test "should cancel active subscriptions before being deleted" do
    assert_equal "active", @subscription.status
    freeze_time do
      @subscription.destroy
      assert_equal "canceled", @subscription.status
    end
  end

  test "generic_trial?" do
    subscription = pay_subscriptions(:fake)
    subscription.update(trial_ends_at: 14.days.from_now)
    assert subscription.generic_trial?

    # Must be fake processor
    subscription = pay_subscriptions(:stripe)
    subscription.update(trial_ends_at: 14.days.from_now)
    refute subscription.generic_trial?
  end

end
