require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionCreatedTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read("test/support/fixtures/stripe/subscription_created_event.json"), object_class: OpenStruct)
  end

  test "subscription is created" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)

    assert_equal 0, @user.subscriptions.count

    Pay::Stripe::Webhooks::SubscriptionCreated.new.call(@event)

    subscription = @user.subscriptions.first

    assert_equal 1, @user.subscriptions.count
    assert_equal "FFBEGINNER_00000000000000", subscription.processor_plan
    assert_equal Time.at(@event.data.object.trial_end), subscription.trial_ends_at
    assert_nil subscription.ends_at
    assert_equal "active", subscription.status
  end

  test "does not create a subscription when the user does not exist" do
    result = Pay::Stripe::Webhooks::SubscriptionCreated.new.call(@event)

    assert_equal 0, Pay.subscription_model.count
    assert_nil result
  end

  test "subscription is updated" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "FFBEGINNER_00000000000000", status: "incomplete", quantity: 2)

    Pay::Stripe::Webhooks::SubscriptionCreated.new.call(@event)

    subscription.reload

    assert_equal 2, subscription.quantity
    assert_equal "FFBEGINNER_00000000000000", subscription.processor_plan
    assert_equal Time.at(@event.data.object.trial_end), subscription.trial_ends_at
    assert_nil subscription.ends_at
    assert_equal "active", subscription.status
  end

  test "subscription is updated with cancel_at_period_end = true and on_trial? = false" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")

    @event.data.object.stubs(:cancel_at_period_end).returns(true)

    Pay::Stripe::Webhooks::SubscriptionCreated.new.call(@event)

    assert_equal Time.at(@event.data.object.current_period_end), subscription.reload.ends_at
  end

  test "subscription is updated with cancel_at_period_end = true and on_trial? = true" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")

    @event.data.object.stubs(:cancel_at_period_end).returns(true)
    Pay.subscription_model.any_instance.stubs(:on_trial?).returns(true)
    Pay.subscription_model.any_instance.stubs(:trial_ends_at).returns(3.days.from_now.beginning_of_day)

    Pay::Stripe::Webhooks::SubscriptionCreated.new.call(@event)

    assert_equal 3.days.from_now.beginning_of_day, subscription.reload.ends_at
  end
end
