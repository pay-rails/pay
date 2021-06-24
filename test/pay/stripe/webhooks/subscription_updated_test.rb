require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/subscription_updated_event.json")
  end

  test "nothing happens if a owner can't be found" do
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription
    Pay.subscription_model.any_instance.expects(:update).never
    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
  end

  test "subscription is updated" do
    build_user

    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(quantity: 2, ended_at: nil, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)

    subscription.reload
    assert_equal 2, subscription.quantity
    assert_equal "FFBEGINNER_00000000000000", subscription.processor_plan
    assert_equal Time.at(@event.data.object.trial_end), subscription.trial_ends_at
    assert_nil subscription.ends_at
  end

  test "subscription is updated with cancel_at_period_end = true and on_trial? = false" do
    build_user

    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(cancel_at_period_end: true, current_period_end: @event.data.object.current_period_end, ended_at: nil, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal Time.at(@event.data.object.current_period_end), subscription.reload.ends_at
  end

  test "subscription is updated with cancel_at_period_end = true and on_trial? = true" do
    build_user

    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    trial_end = 3.days.from_now.beginning_of_day
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(cancel_at_period_end: true, current_period_end: trial_end, ended_at: nil, trial_end: trial_end, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)

    assert_equal 3.days.from_now.beginning_of_day, subscription.reload.ends_at
  end


  test "subscription is updated with ended_at set" do
    build_user

    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    sub_end = 3.days.ago.beginning_of_day
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(cancel_at_period_end: false, ended_at: sub_end, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal sub_end, subscription.reload.ends_at
  end

  test "subscription is updated with cancel_at set" do
    build_user

    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    sub_cancel = 3.days.ago.beginning_of_day
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(ended_at: nil, cancel_at: sub_cancel)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal sub_cancel, subscription.reload.ends_at
  end

  test "subscription was canceled, now renewed" do
    build_user

    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active", ends_at: Time.now)
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(cancel_at_period_end: false, ended_at: nil, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal nil, subscription.reload.ends_at
  end

  def fake_stripe_subscription(**values)
    values.reverse_merge!(@event.data.object.to_hash)
    ::Stripe::Subscription.construct_from(values)
  end

  def build_user
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
  end
end
