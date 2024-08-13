require "test_helper"

class Pay::LemonSqueezy::WebhooksTest < ActiveSupport::TestCase
  test "lemon squeezy order_created webhook" do
    json = json_fixture("lemon_squeezy/order_created")
    event = Pay::Webhook.new(processor: :lemon_squeezy, event: json).rehydrated_event

    user = users(:none)
    user.set_payment_processor :lemon_squeezy, processor_id: event.customer_id

    ::LemonSqueezy::Subscription.expects(:list).returns(OpenStruct.new({data: []}))

    assert_difference "Pay::Charge.count" do
      Pay::LemonSqueezy::Webhooks::Order.new.call(event)
    end

    assert_equal event.total, Pay::Charge.last.amount
  end

  test "lemon squeezy subscription_created webhook" do
    json = json_fixture("lemon_squeezy/subscription_created")
    event = Pay::Webhook.new(processor: :lemon_squeezy, event: json).rehydrated_event

    user = users(:none)
    user.set_payment_processor :lemon_squeezy, processor_id: event.customer_id

    assert_difference "Pay::Subscription.count" do
      Pay::LemonSqueezy::Webhooks::Subscription.new.call(event)
    end
  end

  test "lemon squeezy subscription_updated webhook" do
    json = json_fixture("lemon_squeezy/subscription_updated")
    event = Pay::Webhook.new(processor: :lemon_squeezy, event: json).rehydrated_event

    user = users(:none)
    user.set_payment_processor :lemon_squeezy, processor_id: event.customer_id

    assert_difference "Pay::Subscription.count" do
      Pay::LemonSqueezy::Webhooks::Subscription.new.call(event)
    end
  end

  test "lemon squeezy subscription_payment_success webhook" do
    json = json_fixture("lemon_squeezy/subscription_payment_success")
    event = Pay::Webhook.new(processor: :lemon_squeezy, event: json).rehydrated_event

    user = users(:none)
    user.set_payment_processor :lemon_squeezy, processor_id: event.customer_id
    user.payment_processor.subscriptions.create!(processor_id: event.subscription_id, name: Pay.default_product_name, processor_plan: "Default", status: :active)

    assert_difference "Pay::Charge.count" do
      Pay::LemonSqueezy::Webhooks::SubscriptionPayment.new.call(event)
    end
    charge = Pay::Charge.last
    assert_equal 999, charge.amount
    assert_equal 0, charge.amount_refunded
  end

  test "lemon squeezy subscription_payment_refunded webhook" do
    json = json_fixture("lemon_squeezy/subscription_payment_refunded")
    event = Pay::Webhook.new(processor: :lemon_squeezy, event: json).rehydrated_event

    user = users(:none)
    user.set_payment_processor :lemon_squeezy, processor_id: event.customer_id
    user.payment_processor.subscriptions.create!(processor_id: event.subscription_id, name: Pay.default_product_name, processor_plan: "Default", status: :active)

    assert_difference "Pay::Charge.count" do
      Pay::LemonSqueezy::Webhooks::SubscriptionPayment.new.call(event)
    end

    charge = Pay::Charge.last
    assert_equal 999, charge.amount
    assert_equal 999, charge.amount_refunded
  end
end
