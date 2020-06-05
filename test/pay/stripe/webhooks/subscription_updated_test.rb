require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read("test/support/fixtures/stripe/subscription_updated_event.json"), object_class: OpenStruct)
  end

  test "nothing happens if a subscription can't be found" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    @user.subscriptions.create!(processor: :stripe, processor_id: "does-not-exist", name: "default", processor_plan: "some-plan", status: "active")

    Pay.subscription_model.any_instance.expects(:save).never
    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
  end

  test "subscription is updated" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)

    assert_equal 2, subscription.reload.quantity
    assert_equal "FFBEGINNER_00000000000000", subscription.reload.processor_plan
    assert_equal Time.at(@event.data.object.trial_end), subscription.reload.trial_ends_at
    assert_nil subscription.reload.ends_at
  end

  test "subscription is updated with cancel_at_period_end = true and on_trial? = false" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")

    @event.data.object.stubs(:cancel_at_period_end).returns(true)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)

    assert_equal Time.at(@event.data.object.current_period_end), subscription.reload.ends_at
  end

  test "subscription is updated with cancel_at_period_end = true and on_trial? = true" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")

    @event.data.object.stubs(:cancel_at_period_end).returns(true)
    Pay.subscription_model.any_instance.stubs(:on_trial?).returns(true)
    Pay.subscription_model.any_instance.stubs(:trial_ends_at).returns(3.days.from_now.beginning_of_day)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)

    assert_equal 3.days.from_now.beginning_of_day, subscription.reload.ends_at
  end
end
