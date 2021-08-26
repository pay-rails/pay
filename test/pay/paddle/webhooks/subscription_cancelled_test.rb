require "test_helper"

class Pay::Paddle::Webhooks::SubscriptionCancelledTest < ActiveSupport::TestCase
  setup do
    @data = OpenStruct.new JSON.parse(File.read("test/support/fixtures/paddle/subscription_cancelled.json"))
    @pay_customer = pay_customers(:paddle)
    @pay_customer.update(processor_id: @data.user_id)
  end

  test "it sets ends_at on the subscription" do
    @pay_customer.subscription.update!(processor_id: @data["subscription_id"])
    Pay::Subscription.any_instance.expects(:update!).with(ends_at: Time.zone.parse(@data["cancellation_effective_date"]))
    Pay::Paddle::Webhooks::SubscriptionCancelled.new.call(@data)
  end

  test "it doesn't set ends_at on the subscription if it's already set" do
    @pay_customer.subscription.update!(processor_id: @data["subscription_id"], ends_at: Time.zone.now)
    Pay::Subscription.any_instance.expects(:update!).with(ends_at: Time.zone.parse(@data["cancellation_effective_date"])).never
    Pay::Paddle::Webhooks::SubscriptionCancelled.new.call(@data)
  end

  test "it doesn't set ends_at on the subscription if it can't find the subscription" do
    @pay_customer.subscription.update!(processor_id: "does-not-exist")
    Pay::Subscription.any_instance.expects(:update!).with(ends_at: Time.zone.parse(@data["cancellation_effective_date"])).never
    Pay::Paddle::Webhooks::SubscriptionCancelled.new.call(@data)
  end
end
