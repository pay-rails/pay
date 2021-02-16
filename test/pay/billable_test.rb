require "test_helper"

class Pay::Billable::Test < ActiveSupport::TestCase
  setup do
    @billable = User.new email: "gob@bluth.com"
  end

  test "truth" do
    assert_kind_of Module, Pay::Billable
  end

  test "customer name" do
    assert_equal "", User.new.customer_name
    assert_equal "Gob", User.new(first_name: "Gob").customer_name
    assert_equal "Bluth", User.new(last_name: "Bluth").customer_name
    assert_equal "Gob Bluth", User.new(first_name: "Gob", last_name: "Bluth").customer_name
  end

  test "has charges" do
    assert_equal Pay::Charge.none, @billable.charges
  end

  test "has subscriptions" do
    assert_equal Pay::Subscription.none, @billable.subscriptions
  end

  test "customer with stripe processor" do
    @billable.processor = "stripe"
    Pay::Stripe::Billable.any_instance.expects(:customer).returns(:user)
    assert_equal :user, @billable.customer
  end

  test "customer with undefined processor" do
    @billable.processor = "pants"

    assert_raises NameError do
      @billable.customer
    end
  end

  test "customer without processor" do
    assert_raises StandardError do
      @billable.customer
    end
  end

  test "subscribing a stripe customer" do
    @billable.processor = "stripe"
    Pay::Stripe::Billable.any_instance.expects(:subscribe).returns(:user)
    assert_equal :user, @billable.subscribe
    assert @billable.processor = "stripe"
  end

  test "updating a stripe card" do
    @billable.processor = "stripe"
    @billable.processor_id = 1
    Pay::Stripe::Billable.any_instance.expects(:update_card).with("a1b2c3").returns(:card)
    assert_equal :card, @billable.update_card("a1b2c3")
  end

  test "updating a card without a processor" do
    assert_raises StandardError do
      @billable.update_card("whoops")
    end
  end

  test "checking for a subscription without one" do
    @billable.stubs(:subscription).returns(nil)
    refute @billable.subscribed?
  end

  test "checking for a subscription with no plan and active subscription" do
    subscription = mock("subscription")
    subscription.stubs(:active?).returns(true)
    @billable.stubs(:subscription).returns(subscription)

    assert @billable.subscribed?
  end

  test "checking for a subscription with no plan and inactive subscription" do
    subscription = mock("subscription")
    subscription.stubs(:active?).returns(false)
    @billable.stubs(:subscription).returns(subscription)

    refute @billable.subscribed?
  end

  test "checking for a subscription that is inactive" do
    subscription = mock("subscription")
    subscription.stubs(:active?).returns(false)
    @billable.stubs(:subscription).returns(subscription)

    refute @billable.subscribed?(name: "default", processor_plan: "default")
  end

  test "checking for a subscription that is active for another plan" do
    subscription = mock("subscription")
    subscription.stubs(:active?).returns(true)
    subscription.stubs(:processor_plan).returns("superior")
    @billable.stubs(:subscription).returns(subscription)

    refute @billable.subscribed?(name: "default", processor_plan: "default")
  end

  test "checking for a subscription that is active for a provided plan" do
    subscription = mock("subscription")
    subscription.stubs(:active?).returns(true)
    subscription.stubs(:processor_plan).returns("default")
    @billable.stubs(:subscription).returns(subscription)

    assert @billable.subscribed?(name: "default", processor_plan: "default")
  end

  test "getting a subscription by default name" do
    subscription = Pay.subscription_model.create!(
      name: "default",
      owner: @billable,
      processor: "stripe",
      processor_id: "1",
      processor_plan: "default",
      status: "active",
      quantity: "1"
    )

    assert_equal subscription, @billable.subscription
  end

  test "getting a subscription by default name with subscriptions eager loaded" do
    user = User.new(email: "john@smith.com")
    subscription = Pay.subscription_model.create!(
      name: "default",
      owner: user,
      processor: "stripe",
      processor_id: "1",
      processor_plan: "default",
      status: "active",
      quantity: "1"
    )

    Pay.subscription_model.expects(:for_name).with("default").never

    user_with_subscriptions_loaded = User.includes(:subscriptions).find(user.id)

    assert_equal subscription, user_with_subscriptions_loaded.subscription
  end

  test "getting a stripe subscription" do
    @billable.processor = "stripe"
    ::Stripe::Subscription.expects(:retrieve).with(id: "123").returns(:subscription)

    assert_equal :subscription, @billable.processor_subscription("123")
  end

  test "getting a processor subscription without a processor" do
    assert_raises StandardError do
      @billable.processor_subscription("123")
    end
  end

  test "pay invoice" do
    @billable.processor = "stripe"
    Pay::Stripe::Billable.any_instance.expects(:invoice!).returns(:invoice)
    assert_equal :invoice, @billable.invoice!
  end

  test "get upcoming invoice" do
    @billable.processor = "stripe"
    Pay::Stripe::Billable.any_instance.expects(:upcoming_invoice).returns(:invoice)
    assert_equal :invoice, @billable.upcoming_invoice
  end

  test "on_trial? with no plan" do
    subscription = mock("subscription")
    subscriptions = mock("subscriptions")
    subscriptions.stubs(:last).returns(subscription)
    subscription.stubs(:on_trial?).returns(true)
    @billable.subscriptions.expects(:for_name).with("default").returns(subscriptions)

    assert @billable.on_trial?
  end

  test "on_trial? with no plan and on_generic_trial?" do
    subscription = mock("subscription")
    subscriptions = mock("subscriptions")
    subscriptions.stubs(:last).returns(subscription)
    @billable.stubs(:on_generic_trial?).returns(true)

    assert @billable.on_trial?
  end

  test "on_generic_trial? with a trial_ends_at in the future" do
    @billable.trial_ends_at = 3.days.from_now
    assert @billable.on_generic_trial?
  end

  test "on_generic_trial? with a trial_ends_at in the past" do
    @billable.trial_ends_at = 3.days.ago
    refute @billable.on_generic_trial?
  end

  test "on_trial? with plan matching the subscription plan" do
    plan_name = "PROCESSORPLAN"
    subscription = mock("subscription")
    subscription.stubs(:processor_plan).returns(plan_name)
    subscriptions = mock("subscriptions")
    subscriptions.stubs(:last).returns(subscription)
    subscription.stubs(:on_trial?).returns(true)
    @billable.subscriptions.expects(:for_name).with("default").returns(subscriptions)

    assert @billable.on_trial?(plan: plan_name)
  end

  test "on_trial? with plan different than the subscription plan" do
    plan_name = "PROCESSORPLAN"
    subscription = mock("subscription")
    subscription.stubs(:processor_plan).returns(plan_name)
    subscriptions = mock("subscriptions")
    subscriptions.stubs(:last).returns(subscription)
    subscription.stubs(:on_trial?).returns(true)
    @billable.subscriptions.expects(:for_name).with("default").returns(subscriptions)

    refute @billable.on_trial?(plan: "OTHERPLAN")
  end

  test "on_trial_or_subscribed? with no plan" do
    subscription = mock("subscription")
    subscriptions = mock("subscriptions")
    subscriptions.stubs(:last).returns(subscription)
    subscription.stubs(:on_trial?).returns(true)
    @billable.subscriptions.expects(:for_name).with("default").returns(subscriptions)

    assert @billable.on_trial_or_subscribed?
  end

  test "on_trial_or_subscribed? with no plan and on_generic_trial?" do
    subscription = mock("subscription")
    subscriptions = mock("subscriptions")
    subscriptions.stubs(:last).returns(subscription)
    @billable.stubs(:on_generic_trial?).returns(true)

    assert @billable.on_trial_or_subscribed?
  end

  test "on_trial_or_subscribed? with a subscription that is active for another plan" do
    subscription = mock("subscription")
    subscription.stubs(:active?).returns(true)
    subscription.stubs(:processor_plan).returns("superior")
    subscription.stubs(:on_trial?).returns(false)
    @billable.stubs(:subscription).returns(subscription)

    refute @billable.on_trial_or_subscribed?(name: "default", processor_plan: "default")
  end

  test "on_trial_or_subscribed? with a subscription that is active for a provided plan" do
    subscription = mock("subscription")
    subscription.stubs(:active?).returns(true)
    subscription.stubs(:processor_plan).returns("default")
    subscription.stubs(:on_trial?).returns(false)
    @billable.stubs(:subscription).returns(subscription)

    assert @billable.on_trial_or_subscribed?(name: "default", processor_plan: "default")
  end

  test "updating processor clears processor id" do
    @billable.processor = "stripe"
    @billable.processor_id = 1

    @billable.processor = "braintree"
    assert_nil @billable.processor_id
  end

  test "finds polymorphic subscription" do
    user_billable = User.create! email: "test@example.com", id: 1001
    team_billable = Team.create! id: 1001, owner: user_billable

    subscription = Pay.subscription_model.create!(
      owner: team_billable, name: "default", processor: "stripe", processor_id: "1",
      processor_plan: "default", quantity: "1", status: "active"
    )

    assert_nil user_billable.subscription
    assert_equal subscription, team_billable.subscription
  end
end
