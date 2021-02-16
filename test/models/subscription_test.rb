require "test_helper"

class Pay::Subscription::Test < ActiveSupport::TestCase
  setup do
    @owner = User.create email: "bill@microsoft.com"
    @subscription = Pay.subscription_model.new processor: "stripe", status: "active"
  end

  test "belongs to a polymorphic owner" do
    @subscription.owner = @owner
    assert_equal User, @subscription.owner.class
    @subscription.owner = Team.new
    assert_equal Team, @subscription.owner.class
  end

  test "braintree?" do
    assert @subscription.respond_to?(:braintree?)
  end

  test "stripe?" do
    assert @subscription.respond_to?(:stripe?)
  end

  test "paddle?" do
    assert @subscription.respond_to?(:paddle?)
  end

  test "braintree scope" do
    assert Pay.subscription_model.braintree.is_a?(ActiveRecord::Relation)
  end

  test "stripe scope" do
    assert Pay.subscription_model.stripe.is_a?(ActiveRecord::Relation)
  end

  test "paddle scope" do
    assert Pay.subscription_model.paddle.is_a?(ActiveRecord::Relation)
  end

  test ".for_name(name) scope" do
    subscription1 = create_subscription(name: "default")
    subscription2 = create_subscription(name: "superior")

    subscriptions = Pay.subscription_model.for_name("default")
    assert_includes subscriptions, subscription1
    refute_includes subscriptions, subscription2
  end

  test "on trial scope" do
    subscription1 = create_subscription(trial_ends_at: 7.days.from_now)
    subscription2 = create_subscription(trial_ends_at: nil)
    subscription3 = create_subscription(trial_ends_at: 7.days.ago)

    subscriptions = Pay.subscription_model.on_trial

    assert_includes subscriptions, subscription1
    refute_includes subscriptions, subscription2
    refute_includes subscriptions, subscription3
  end

  test "cancelled scope" do
    subscription1 = create_subscription(ends_at: 7.days.ago)
    subscription2 = create_subscription(ends_at: 7.days.from_now)
    subscription3 = create_subscription(ends_at: nil)

    subscriptions = Pay.subscription_model.cancelled

    assert_includes subscriptions, subscription1
    assert_includes subscriptions, subscription2
    refute_includes subscriptions, subscription3
  end

  test "on grace period scope" do
    subscription1 = create_subscription(ends_at: 7.days.from_now)
    subscription2 = create_subscription(ends_at: nil)
    subscription3 = create_subscription(ends_at: 7.days.ago)

    subscriptions = Pay.subscription_model.on_grace_period

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

    subscriptions = Pay.subscription_model.active

    assert_includes subscriptions, subscription1
    assert_includes subscriptions, subscription2
    assert_includes subscriptions, subscription3
    refute_includes subscriptions, subscription4
    refute_includes subscriptions, subscription5
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
    expiration = 2.weeks.from_now

    stripe_sub = mock("stripe_subscription")
    stripe_sub.expects(:cancel_at_period_end=).with(true)
    stripe_sub.expects(:save)
    stripe_sub.expects(:current_period_end).returns(expiration)

    @subscription.stubs(:processor_subscription).returns(stripe_sub)
    @subscription.cancel

    assert_in_delta @subscription.ends_at, expiration, 1.second
  end

  test "cancel_now!" do
    cancelled_stripe = mock("cancelled_stripe_subscription")

    stripe_sub = mock("stripe_subscription")
    stripe_sub.expects(:delete).returns(cancelled_stripe)

    @subscription.stubs(:processor_subscription).returns(stripe_sub)
    @subscription.cancel_now!

    assert @subscription.ends_at <= Time.zone.now
  end

  test "resume on grace period" do
    @subscription.ends_at = 2.weeks.from_now

    stripe_sub = mock("stripe_subscription")
    stripe_sub.expects(:plan=)
    stripe_sub.expects(:trial_end=)
    stripe_sub.expects(:cancel_at_period_end=)
    stripe_sub.expects(:save).returns(true)

    @subscription.processor_plan = "default"

    @subscription.stubs(:on_grace_period?).returns(true)
    @subscription.stubs(:processor_subscription).returns(stripe_sub)
    @subscription.stubs(:on_trial?).returns(false)

    @subscription.resume

    assert_nil @subscription.ends_at
  end

  test "resume off grace period" do
    @subscription.stubs(:on_grace_period?).returns(false)

    assert_raises StandardError do
      @subscription.resume
    end
  end

  test "processor subscription" do
    user = mock("user")
    user.expects(:processor_subscription).returns(:result)

    @subscription.stubs(:owner).returns(user)

    assert_equal :result, @subscription.processor_subscription
  end

  test "can swap plans" do
    stripe_sub = mock("stripe_subscription")
    stripe_sub.expects(:cancel_at_period_end=)
    stripe_sub.expects(:plan=).returns("yearly")
    stripe_sub.expects(:proration_behavior=)
    stripe_sub.expects(:trial_end=)
    stripe_sub.expects(:quantity=)
    stripe_sub.expects(:save)
    stripe_sub.expects(:plan).returns("yearly")

    @subscription.stubs(:processor_subscription).returns(stripe_sub)
    @subscription.swap("yearly")

    assert_equal "yearly", @subscription.processor_subscription.plan
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
    assert_not Pay::Subscription.new(processor: :stripe, status: :active, ends_at: 1.day.ago).active?
    assert Pay::Subscription.new(processor: :stripe, status: :active, ends_at: 1.day.ago).canceled?
  end

  private

  def create_subscription(options = {})
    defaults = {
      name: "default",
      owner: @owner,
      processor: "stripe",
      processor_id: "1",
      processor_plan: "default",
      quantity: "1",
      status: "active"
    }

    Pay.subscription_model.create! defaults.merge(options)
  end
end
