require "test_helper"

class Pay::PaddleBilling::SubscriptionTest < ActiveSupport::TestCase
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
    object = paddle_billing_subscription_event("status" => "canceled")

    subscription = Pay::PaddleBilling::Subscription.sync(object.id, object: object)

    assert_equal "canceled", subscription.status
    assert_empty @pay_customer.payment_methods.reload
  end

  test "paddle billing sync retries with a fresh read after a stale lookup" do
    object = paddle_billing_subscription_event
    existing = @pay_customer.subscriptions.create!(processor_id: object.id, name: "default", processor_plan: "default", status: "active")
    Pay::PaddleBilling::Subscription.stubs(:find_by).returns(nil).then.returns(existing)
    ::Paddle::Subscription.expects(:retrieve).with(id: object.id).twice.returns(object)
    Pay::PaddleBilling::Subscription.stubs(:sleep)

    assert_equal existing, Pay::PaddleBilling::Subscription.sync(object.id)
  end

  test "paddle billing pause keeps the subscription active until the pause starts" do
    pay_subscription = pay_subscriptions(:paddle_billing)
    pause_starts_at = 10.days.from_now.change(usec: 0)
    ::Paddle::Subscription.expects(:pause).with(id: pay_subscription.processor_id).returns(
      ::Paddle::Subscription.new(status: "active", paused_at: nil, scheduled_change: {action: "pause", effective_at: pause_starts_at.iso8601, resume_at: nil})
    )

    pay_subscription.pause

    assert_equal "active", pay_subscription.status
    assert_equal pause_starts_at, pay_subscription.pause_starts_at
    assert pay_subscription.paused?
    assert pay_subscription.on_grace_period?
    assert pay_subscription.active?
    assert pay_subscription.resumable?
    assert_includes Pay::Subscription.active, pay_subscription

    # Without a webhook, the pause still takes effect when the period ends
    travel_to 11.days.from_now do
      assert pay_subscription.paused?
      refute pay_subscription.on_grace_period?
      refute pay_subscription.active?
      assert pay_subscription.resumable?
      assert_includes Pay::Subscription.paused, pay_subscription
      refute_includes Pay::Subscription.active, pay_subscription
    end
  end

  test "paddle billing sync of a scheduled pause matches pausing locally" do
    pause_starts_at = 10.days.from_now.change(usec: 0)
    object = paddle_billing_subscription_event("scheduled_change" => {"action" => "pause", "effective_at" => pause_starts_at.iso8601, "resume_at" => nil})

    pay_subscription = Pay::PaddleBilling::Subscription.sync(object.id, object: object)

    assert_equal "active", pay_subscription.status
    assert_equal pause_starts_at, pay_subscription.pause_starts_at
    assert pay_subscription.paused?
    assert pay_subscription.on_grace_period?
    assert pay_subscription.active?
    assert pay_subscription.resumable?
  end

  test "paddle billing sync of a paused subscription is paused and not active" do
    object = paddle_billing_subscription_event("status" => "paused", "paused_at" => 1.day.ago.iso8601)

    pay_subscription = Pay::PaddleBilling::Subscription.sync(object.id, object: object)

    assert pay_subscription.paused?
    refute pay_subscription.on_grace_period?
    refute pay_subscription.active?
    assert pay_subscription.resumable?
  end

  test "paddle billing resume before the pause starts removes the scheduled pause" do
    pay_subscription = pay_subscriptions(:paddle_billing)
    pay_subscription.update!(pause_starts_at: 10.days.from_now)
    ::Paddle::Subscription.expects(:update).with(id: pay_subscription.processor_id, scheduled_change: nil)
    ::Paddle::Subscription.expects(:resume).never

    pay_subscription.resume

    assert_equal "active", pay_subscription.status
    assert_nil pay_subscription.pause_starts_at
    refute pay_subscription.paused?
    assert pay_subscription.active?
  end

  test "paddle billing resume after the pause starts resumes immediately" do
    pay_subscription = pay_subscriptions(:paddle_billing)
    pay_subscription.update!(status: "paused", pause_starts_at: 1.day.ago)
    ::Paddle::Subscription.expects(:resume).with(id: pay_subscription.processor_id, effective_from: "immediately")

    pay_subscription.resume

    assert_equal "active", pay_subscription.status
    refute pay_subscription.paused?
    assert pay_subscription.active?
  end

  test "paddle billing cancel with a scheduled pause removes the pause and cancels at the end of the period" do
    pay_subscription = pay_subscriptions(:paddle_billing)
    pay_subscription.update!(pause_starts_at: 10.days.from_now)
    ends_at = 10.days.from_now.change(usec: 0)
    ::Paddle::Subscription.expects(:update).with(id: pay_subscription.processor_id, scheduled_change: nil)
    ::Paddle::Subscription.expects(:cancel).with(id: pay_subscription.processor_id, effective_from: "next_billing_period").returns(
      ::Paddle::Subscription.new(status: "active", scheduled_change: {action: "cancel", effective_at: ends_at.iso8601})
    )

    pay_subscription.cancel

    assert_equal ends_at, pay_subscription.ends_at
    assert_nil pay_subscription.pause_starts_at
    refute pay_subscription.paused?
    assert pay_subscription.on_grace_period?
    assert pay_subscription.active?
  end

  test "paddle billing cancel_now! with a scheduled pause removes the pause and cancels immediately" do
    pay_subscription = pay_subscriptions(:paddle_billing)
    pay_subscription.update!(pause_starts_at: 10.days.from_now)
    ::Paddle::Subscription.expects(:update).with(id: pay_subscription.processor_id, scheduled_change: nil)
    ::Paddle::Subscription.expects(:cancel).with(id: pay_subscription.processor_id, effective_from: "immediately").returns(
      ::Paddle::Subscription.new(status: "canceled", scheduled_change: nil)
    )

    pay_subscription.cancel_now!

    assert_equal "canceled", pay_subscription.status
    assert_nil pay_subscription.pause_starts_at
    refute pay_subscription.active?
  end

  test "paddle billing cancel of a paused subscription cancels immediately" do
    pay_subscription = pay_subscriptions(:paddle_billing)
    pay_subscription.update!(status: "paused", pause_starts_at: 1.day.ago)
    ::Paddle::Subscription.expects(:update).never
    ::Paddle::Subscription.expects(:cancel).with(id: pay_subscription.processor_id, effective_from: "immediately").returns(
      ::Paddle::Subscription.new(status: "canceled", scheduled_change: nil)
    )

    pay_subscription.cancel

    assert_equal "canceled", pay_subscription.status
  end

  test "pay_processor is derived from the class namespace" do
    assert_equal "paddle_billing", Pay::PaddleBilling::Subscription.pay_processor
    assert_equal "lemon_squeezy", Pay::LemonSqueezy::Charge.pay_processor
    assert_equal "stripe", Pay::Stripe::PaymentMethod.pay_processor
  end

  private

  def paddle_billing_subscription_event(**data)
    paddle_billing_event("subscription.created", overrides: {"data" => data.stringify_keys.merge("customer_id" => @pay_customer.processor_id)})
  end
end
