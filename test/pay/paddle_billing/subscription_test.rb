require "test_helper"

class Pay::PaddleBilling::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_billing)
  end

  test "sync_from_transaction is deprecated in favor of Pay::PaddleBilling.sync_transaction" do
    Pay::PaddleBilling.expects(:sync_transaction).with("txn_1").returns(:synced)

    assert_deprecated(/Pay::PaddleBilling.sync_transaction/, Pay.deprecator) do
      assert_equal :synced, Pay::PaddleBilling::Subscription.sync_from_transaction("txn_1")
    end
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

  test "paddle billing sync retries with a fresh read after a stale lookup" do
    json = json_fixture("paddle_billing/subscription.created").deep_merge("data" => {"customer_id" => @pay_customer.processor_id})
    object = Pay::Webhook.new(processor: :paddle_billing, event: json).rehydrated_event
    existing = @pay_customer.subscriptions.create!(processor_id: object.id, name: "default", processor_plan: "default", status: "active")
    Pay::PaddleBilling::Subscription.stubs(:find_by).returns(nil).then.returns(existing)
    ::Paddle::Subscription.expects(:retrieve).with(id: object.id).twice.returns(object)
    Pay::PaddleBilling::Subscription.stubs(:sleep)

    assert_equal existing, Pay::PaddleBilling::Subscription.sync(object.id)
  end

  test "pay_processor is derived from the class namespace" do
    assert_equal "paddle_billing", Pay::PaddleBilling::Subscription.pay_processor
    assert_equal "lemon_squeezy", Pay::LemonSqueezy::Charge.pay_processor
    assert_equal "stripe", Pay::Stripe::PaymentMethod.pay_processor
  end
end
