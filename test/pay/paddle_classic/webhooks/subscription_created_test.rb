require "test_helper"

class Pay::PaddleClassic::Webhooks::SubscriptionCreatedTest < ActiveSupport::TestCase
  setup do
    @event = paddle_classic_event("subscription_created")
    @user = users(:paddle_classic)
  end

  test "paddle classic passthrough" do
    json = JSON.parse Pay::PaddleClassic.passthrough(owner: @user, foo: :bar)
    assert_equal "bar", json["foo"]
    assert_equal @user, GlobalID::Locator.locate_signed(json["owner_sgid"])
  end

  test "a subscription is created" do
    assert_difference "Pay::Subscription.count" do
      @event.passthrough = Pay::PaddleClassic.passthrough(owner: @user)
      Pay::PaddleClassic::Webhooks::SubscriptionCreated.new.call(@event)
    end

    @user.reload

    assert_equal "paddle_classic", @user.payment_processor.processor
    assert_equal @event.user_id, @user.payment_processor.processor_id

    subscription = Pay::Subscription.last
    assert_equal @event.quantity.to_i, subscription.quantity
    assert_equal @event.subscription_plan_id, subscription.processor_plan
    assert_equal @event.update_url, subscription.paddle_update_url
    assert_equal @event.cancel_url, subscription.paddle_cancel_url
    assert_equal Time.zone.parse(@event.next_bill_date), subscription.trial_ends_at
    assert_nil subscription.ends_at
  end

  test "a subscription isn't created if no corresponding owner can be found" do
    @event.passthrough = "does-not-exist"

    assert_no_difference "Pay::Subscription.count" do
      Pay::PaddleClassic::Webhooks::SubscriptionCreated.new.call(@event)
    end
  end
end
