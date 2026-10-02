require "test_helper"

class Pay::PaddleClassic::Webhooks::SubscriptionUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = paddle_classic_event("subscription_updated")
    @pay_customer = pay_customers(:paddle_classic)
    @pay_customer.update(processor_id: @event.user_id)
    @pay_customer.subscription.update(processor_id: @event.subscription_id)
  end

  test "nothing happens if a subscription can't be found" do
    @pay_customer.subscription.update!(processor_id: "does-not-exist")
    Pay::Subscription.any_instance.expects(:save).never
    Pay::PaddleClassic::Webhooks::SubscriptionUpdated.new.call(@event)
  end

  test "subscription is updated" do
    Pay::PaddleClassic::Webhooks::SubscriptionUpdated.new.call(@event)
    subscription.reload

    assert_equal 2, subscription.quantity
    assert_equal @event.subscription_plan_id, subscription.processor_plan
    assert_equal @event.update_url, subscription.paddle_update_url
    assert_equal @event.cancel_url, subscription.paddle_cancel_url
    assert_nil subscription.trial_ends_at
    assert_nil subscription.ends_at
  end

  test "subscription is updated with subscription status = trialing" do
    @event.status = "trialing"
    Pay::PaddleClassic::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal Time.zone.parse(@event.next_bill_date), subscription.reload.trial_ends_at
    assert_nil subscription.reload.ends_at
  end

  test "subscription is updated with subscription status = deleted and on_trial? = false" do
    @event.status = "deleted"
    Pay::PaddleClassic::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal Time.zone.parse(@event.next_bill_date), subscription.reload.ends_at
  end

  test "subscription is updated with subscription status = paused and on_trial? = true" do
    @event.status = "paused"
    Pay::PaddleClassic::Subscription.any_instance.stubs(:on_trial?).returns(true)
    Pay::PaddleClassic::Subscription.any_instance.stubs(:trial_ends_at).returns(3.days.from_now.beginning_of_day)
    Pay::PaddleClassic::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal 3.days.from_now.beginning_of_day, subscription.reload.ends_at
  end

  private

  def subscription
    @pay_customer.subscription
  end
end
