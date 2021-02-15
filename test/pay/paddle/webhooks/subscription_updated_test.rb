require "test_helper"

class Pay::Paddle::Webhooks::SubscriptionUpdatedTest < ActiveSupport::TestCase
  setup do
    @data = JSON.parse(File.read("test/support/fixtures/paddle/subscription_updated.json"))
  end

  test "nothing happens if a subscription can't be found" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])
    @user.subscriptions.create!(processor: :paddle, processor_id: "does-not-exist", name: "default", processor_plan: "some-plan", status: "active")

    Pay.subscription_model.any_instance.expects(:save).never
    Pay::Paddle::Webhooks::SubscriptionUpdated.new.call(@data)
  end

  test "subscription is updated" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])
    subscription = @user.subscriptions.create!(processor: :paddle, processor_id: @data["subscription_id"], name: "default", processor_plan: "some-plan", status: "active")

    Pay::Paddle::Webhooks::SubscriptionUpdated.new.call(@data)
    subscription.reload

    assert_equal 2, subscription.quantity
    assert_equal @data["subscription_plan_id"], subscription.processor_plan
    assert_equal @data["update_url"], subscription.paddle_update_url
    assert_equal @data["cancel_url"], subscription.paddle_cancel_url
    assert_nil subscription.trial_ends_at
    assert_nil subscription.ends_at
  end

  test "subscription is updated with subscription status = trialing" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])
    subscription = @user.subscriptions.create!(processor: :paddle, processor_id: @data["subscription_id"], name: "default", processor_plan: "some-plan", status: "active")

    @data["status"] = "trialing"

    Pay::Paddle::Webhooks::SubscriptionUpdated.new.call(@data)

    assert_equal Time.zone.parse(@data["next_bill_date"]), subscription.reload.trial_ends_at
    assert_nil subscription.reload.ends_at
  end

  test "subscription is updated with subscription status = deleted and on_trial? = false" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])
    subscription = @user.subscriptions.create!(processor: :paddle, processor_id: @data["subscription_id"], name: "default", processor_plan: "some-plan", status: "active")

    @data["status"] = "deleted"

    Pay::Paddle::Webhooks::SubscriptionUpdated.new.call(@data)

    assert_equal Time.zone.parse(@data["next_bill_date"]), subscription.reload.ends_at
  end

  test "subscription is updated with subscription status = paused and on_trial? = true" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])
    subscription = @user.subscriptions.create!(processor: :paddle, processor_id: @data["subscription_id"], name: "default", processor_plan: "some-plan", status: "active")

    @data["status"] = "paused"
    Pay.subscription_model.any_instance.stubs(:on_trial?).returns(true)
    Pay.subscription_model.any_instance.stubs(:trial_ends_at).returns(3.days.from_now.beginning_of_day)

    Pay::Paddle::Webhooks::SubscriptionUpdated.new.call(@data)

    assert_equal 3.days.from_now.beginning_of_day, subscription.reload.ends_at
  end
end
