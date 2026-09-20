require "test_helper"

class Pay::PaddleBilling::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_billing)
  end

  test "paddle billing processor subscription" do
    assert_equal @pay_customer.subscription.api_record.class, ::Paddle::Subscription
    assert_equal "active", @pay_customer.subscription.status
  end

  test "paddle billing can swap plans" do
    @pay_customer.subscription.swap("pri_01h7qfsc8apejhjgqqx50rghdz")
    assert_equal "pri_01h7qfsc8apejhjgqqx50rghdz", @pay_customer.subscription.api_record.items.first.price.id
    assert_equal "active", @pay_customer.subscription.status
  end

  test "paddle billing sync of a canceled subscription removes the customer's payment methods" do
    @pay_customer.payment_methods.create!(processor_id: "pm_paddle", payment_method_type: "card")
    json = json_fixture("paddle_billing/subscription.created").deep_merge("data" => {"status" => "canceled", "customer_id" => @pay_customer.processor_id})
    object = Pay::Webhook.new(processor: :paddle_billing, event: json).rehydrated_event

    subscription = Pay::PaddleBilling::Subscription.sync(object.id, object: object)

    assert_equal "canceled", subscription.status
    assert_empty @pay_customer.payment_methods.reload
  end
end
