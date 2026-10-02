require "test_helper"

class Pay::LemonSqueezy::Webhooks::SubscriptionTest < ActiveSupport::TestCase
  test "lemon squeezy subscription_created webhook" do
    event = lemon_squeezy_event("subscription_created")
    users(:none).set_payment_processor :lemon_squeezy, processor_id: event.customer_id

    assert_difference "Pay::Subscription.count" do
      Pay::LemonSqueezy::Webhooks::Subscription.new.call(event)
    end
  end

  test "lemon squeezy subscription_updated webhook" do
    event = lemon_squeezy_event("subscription_updated")
    users(:none).set_payment_processor :lemon_squeezy, processor_id: event.customer_id

    assert_difference "Pay::Subscription.count" do
      Pay::LemonSqueezy::Webhooks::Subscription.new.call(event)
    end
  end
end
