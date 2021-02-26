require "test_helper"

class Pay::Paddle::Webhooks::SubscriptionCancelledTest < ActiveSupport::TestCase
  setup do
    @data = JSON.parse(File.read("test/support/fixtures/paddle/subscription_cancelled.json"))
  end

  test "it sets ends_at on the subscription" do
    @user = User.create!(
      email: "gob@bluth.com",
      processor: :paddle,
      processor_id: @data["user_id"]
    )
    @user.subscriptions.create!(
      processor: :paddle,
      processor_id: @data["subscription_id"],
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay.subscription_model.any_instance.expects(:update!).with(ends_at: Time.zone.parse(@data["cancellation_effective_date"]))
    Pay::Paddle::Webhooks::SubscriptionCancelled.new.call(@data)
  end

  test "it doesn't set ends_at on the subscription if it's already set" do
    @user = User.create!(
      email: "gob@bluth.com",
      processor: :paddle,
      processor_id: @data["user_id"]
    )
    @user.subscriptions.create!(
      processor: :paddle,
      processor_id: @data["subscription_id"],
      name: "default",
      processor_plan: "some-plan",
      ends_at: Time.zone.now,
      status: "active"
    )

    Pay.subscription_model.any_instance.expects(:update!).with(ends_at: Time.zone.parse(@data["cancellation_effective_date"])).never
    Pay::Paddle::Webhooks::SubscriptionCancelled.new.call(@data)
  end

  test "it doesn't set ends_at on the subscription if it can't find the subscription" do
    @user = User.create!(
      email: "gob@bluth.com",
      processor: :paddle,
      processor_id: @data["user_id"]
    )
    @user.subscriptions.create!(
      processor: :paddle,
      processor_id: "does-not-exist",
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay.subscription_model.any_instance.expects(:update!).with(ends_at: Time.zone.parse(@data["cancellation_effective_date"])).never
    Pay::Paddle::Webhooks::SubscriptionCancelled.new.call(@data)
  end
end
