require "test_helper"

class Pay::PaddleClassic::Webhooks::SubscriptionCancelledTest < ActiveSupport::TestCase
  setup do
    @data = OpenStruct.new json_fixture("paddle_classic/subscription_cancelled")
    @pay_customer = pay_customers(:paddle_classic)
    @pay_customer.update(processor_id: @data.user_id)
  end

  test "it sets ends_at on the subscription" do
    @pay_customer.subscription.update!(processor_id: @data["subscription_id"])
    Pay::Subscription.any_instance.expects(:update!).with(
      status: :canceled,
      trial_ends_at: nil,
      ends_at: Time.zone.parse(@data["cancellation_effective_date"])
    )
    Pay::PaddleClassic::Webhooks::SubscriptionCancelled.new.call(@data)
  end

  # Paddle subscriptions are canceled immediately, however we still want to give the user access to the end of the period they paid for
  test "it sets status active on the subscription canceled with a future ends_at" do
    @data = paddle_classic_event("subscription_cancelled", overrides: {
      cancellation_effective_date: 1.month.from_now.to_formatted_s(:db)
    })
    @pay_customer.subscription.update!(processor_id: @data["subscription_id"])
    Pay::Subscription.any_instance.expects(:update!).with(
      status: :active,
      trial_ends_at: nil,
      ends_at: Time.zone.parse(@data["cancellation_effective_date"])
    )
    Pay::PaddleClassic::Webhooks::SubscriptionCancelled.new.call(@data)
  end

  test "it sets trial_ends_at on subscription with trial" do
    @pay_customer.subscription.update!(processor_id: @data["subscription_id"], trial_ends_at: 1.month.ago)
    Pay::Subscription.any_instance.expects(:update!).with(
      status: :canceled,
      trial_ends_at: Time.zone.parse(@data["cancellation_effective_date"]),
      ends_at: Time.zone.parse(@data["cancellation_effective_date"])
    )
    Pay::PaddleClassic::Webhooks::SubscriptionCancelled.new.call(@data)
  end

  test "it doesn't set ends_at on the subscription if it can't find the subscription" do
    @pay_customer.subscription.update!(processor_id: "does-not-exist")
    Pay::Subscription.any_instance.expects(:update!).with(
      status: :canceled,
      trial_ends_at: nil,
      ends_at: Time.zone.parse(@data["cancellation_effective_date"])
    ).never
    Pay::PaddleClassic::Webhooks::SubscriptionCancelled.new.call(@data)
  end
end
