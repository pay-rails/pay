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

  test "paddle_classic?" do
    assert pay_subscriptions(:paddle_classic).paddle_classic?
    refute pay_subscriptions(:fake).paddle_classic?
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

  test "paddle_classic scope" do
    assert Pay::Subscription.paddle_classic.is_a?(ActiveRecord::Relation)
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

  test "active scope should include active subscriptions" do
    active_subscription = create_subscription
    subscriptions = Pay::Subscription.active
    assert_includes subscriptions, active_subscription
  end

  test "active scope should include subscriptions on a grace period" do
    grace_period_subscription = create_subscription(ends_at: 7.days.from_now)
    subscriptions = Pay::Subscription.active
    assert_includes subscriptions, grace_period_subscription
  end

  test "active scope should include trialing subscriptions" do
    trialing_subscription = create_subscription(trial_ends_at: 7.days.from_now)
    subscriptions = Pay::Subscription.active
    assert_includes subscriptions, trialing_subscription
  end

  test "active scope should include previously trialed subscriptions" do
    trialing_subscription = create_subscription(trial_ends_at: 7.days.ago)
    subscriptions = Pay::Subscription.active
    assert_includes subscriptions, trialing_subscription
  end

  test "active scope should not include paused subscriptions" do
    paused_subscription = create_subscription(status: "paused")
    subscriptions = Pay::Subscription.active
    refute_includes subscriptions, paused_subscription
  end

  test "active scope should not include ended subscriptions" do
    ended_subscription = create_subscription(ends_at: 7.days.ago)
    subscriptions = Pay::Subscription.active
    refute_includes subscriptions, ended_subscription
  end

  test "active scope should not include ended trial subscriptions" do
    trial_ended_subscription = create_subscription(ends_at: 8.days.ago, trial_ends_at: 7.days.ago)
    subscriptions = Pay::Subscription.active
    refute_includes subscriptions, trial_ended_subscription
  end

  test "active scope includes future Stripe paused subscription" do
    subscription = create_stripe_subscription(pause_behavior: "void", pause_starts_at: 1.day.from_now)
    subscriptions = Pay::Subscription.active
    assert_includes subscriptions, subscription
  end

  test "active scope includes Stripe paused keep_as_draft subscription" do
    subscription = create_stripe_subscription(pause_behavior: "keep_as_draft")
    subscriptions = Pay::Subscription.active
    assert_includes subscriptions, subscription
  end

  test "active scope includes Stripe paused mark_uncollectible subscription" do
    subscription = create_stripe_subscription(pause_behavior: "mark_uncollectible")
    subscriptions = Pay::Subscription.active
    assert_includes subscriptions, subscription
  end

  test "active scope does not include Stripe paused subscription" do
    subscription = create_stripe_subscription(pause_behavior: "void", pause_starts_at: 1.day.ago)
    subscriptions = Pay::Subscription.active
    refute_includes subscriptions, subscription
  end

  test "active scope does not include Paddle paused subscriptions" do
    subscription = create_paddle_subscription(status: "paused")
    subscriptions = Pay::Subscription.active
    refute_includes subscriptions, subscription
  end

  test "active scope with multiple paused subscriptions from various processors" do
    active_subscription = create_subscription
    paused_subscription1 = create_stripe_subscription(pause_behavior: "void", pause_starts_at: 1.day.ago)
    paused_subscription2 = create_paddle_subscription(status: "paused")

    subscriptions = Pay::Subscription.active

    assert_includes subscriptions, active_subscription
    refute_includes subscriptions, paused_subscription1
    refute_includes subscriptions, paused_subscription2
  end

  test "paused scope includes Stripe paused subscription" do
    subscription = create_stripe_subscription(pause_behavior: "void", pause_starts_at: 1.day.ago)
    subscriptions = Pay::Subscription.paused
    assert_includes subscriptions, subscription
  end

  test "paused scope does not include future Stripe paused subscription" do
    subscription = create_stripe_subscription(pause_behavior: "void", pause_starts_at: 1.day.from_now)
    subscriptions = Pay::Subscription.paused
    refute_includes subscriptions, subscription
  end

  test "paused scope includes Paddle paused subscription" do
    subscription = create_paddle_subscription(status: "paused")
    subscriptions = Pay::Subscription.paused
    assert_includes subscriptions, subscription
  end

  test "active_or_paused scope should include paused subscriptions" do
    paused_subscription = create_subscription(status: "paused")
    paused_subscription2 = create_subscription(status: "active", pause_behavior: "void", pause_starts_at: 1.day.from_now)
    subscriptions = Pay::Subscription.active_or_paused
    assert_includes subscriptions, paused_subscription
    assert_includes subscriptions, paused_subscription2
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

  test "#trial_ended? where a subscriptions trial_ends_at is in the past should return true" do
    @subscription.trial_ends_at = 5.days.ago
    assert @subscription.trial_ended?
  end

  test "#trial_ended? where a subscriptions trial_ends_at is in the future should return false" do
    @subscription.trial_ends_at = 5.days.from_now
    refute @subscription.trial_ended?
  end

  test "#has_trial? should return true if a subscriptions trial_ends_at is truthy" do
    @subscription.trial_ends_at = 5.days.from_now
    assert @subscription.has_trial?

    @subscription.trial_ends_at = 5.days.ago
    assert @subscription.has_trial?
  end

  test "#has_trial? should return false if a subscriptions trial_ends_at is nil" do
    @subscription.trial_ends_at = nil
    refute @subscription.has_trial?
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

  test "past_due" do
    @subscription.update!(status: :past_due)
    refute @subscription.active?
    assert_not_includes @pay_customer.subscriptions.active, @subscription
  end

  test "unpaid" do
    @subscription.update!(status: :unpaid)
    refute @subscription.active?
    assert_not_includes @pay_customer.subscriptions.active, @subscription
  end

  test "canceled subscriptions with a future ends_at are inactive" do
    @subscription.update(status: :canceled, ends_at: 1.hour.from_now)
    refute @subscription.active?
    assert_not_includes @pay_customer.subscriptions.active, @subscription
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

  test "api_record" do
    @subscription.stubs(:api_record).returns(:result)
    assert_equal :result, @subscription.api_record
  end

  test "can swap plans" do
    @subscription.swap("small-annual")
    assert_equal "small-annual", @subscription.processor_plan
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

  test "subscription should be consistent regardless of loaded subscriptions or not" do
    # This test assures a consistent pay_customer#subscription regardless of
    # pay_customer#subscriptions being previously loaded or not.

    # Before the introduction of the scope `-> { order({ id: :asc }) }` in
    # Customer.has_many(:subscriptions), calling customer#subscription was
    # non-deterministic if the subscriptions were already loaded.

    # That happened because in Postgres, if an order clause is not specified,
    # the results return in non-deterministic order
    # (https://stackoverflow.com/questions/6585574/postgres-default-sort-by-id-worldship).

    # Psql will give the impression of returning records in ascending primary
    # key (ID) order, but it turns out if you update a previously created
    # record, it will start appearing first. This is what this test simulates
    # by updating subscription_1.

    # If that association scope is removed, this test fails in psql only
    # (see bin/test_databases for multi-db tests).

    @pay_customer = pay_customers(:stripe)
    subscription_1 = create_subscription(processor_id: 1)

    assert_equal subscription_1, @pay_customer.subscription

    subscription_2 = create_subscription(status: "canceled", processor_id: 2)

    assert_equal subscription_2, @pay_customer.subscription
    assert_equal subscription_2, @pay_customer.subscription

    subscription_1.update_columns(status: "canceled")

    @pay_customer.reload
    assert_not @pay_customer.subscriptions.loaded?

    @pay_customer.subscriptions.load
    assert_equal subscription_2, @pay_customer.subscription
  end

  test "can be associated with a payment method" do
    assert_equal pay_payment_methods(:one), pay_subscriptions(:stripe).payment_method
  end

  test "payment method association is optional" do
    assert_nil pay_subscriptions(:fake).payment_method
  end

  private

  def create_subscription(options = {})
    defaults = {
      name: "default",
      processor_id: rand(1..999_999_999),
      processor_plan: "default",
      quantity: "1",
      status: :active
    }

    @pay_customer.subscriptions.create! defaults.merge(options)
  end

  def create_stripe_subscription(options = {})
    defaults = {
      name: "default",
      processor_id: rand(1..999_999_999),
      processor_plan: "default",
      quantity: "1",
      status: :active
    }

    pay_customers(:stripe).subscriptions.create! defaults.merge(options)
  end

  def create_paddle_subscription(options = {})
    defaults = {
      name: "default",
      processor_id: rand(1..999_999_999),
      processor_plan: "default",
      quantity: "1",
      status: :active
    }

    pay_customers(:paddle_classic).subscriptions.create! defaults.merge(options)
  end
end
