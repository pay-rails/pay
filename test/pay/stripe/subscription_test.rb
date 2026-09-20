require "test_helper"

class Pay::Stripe::SubscriptionTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:stripe)
  end

  test "stripe sync skips subscription without customer" do
    @pay_customer.update!(processor_id: nil)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(customer: nil, status: "past_due"))
    assert_nil pay_subscription
  end

  test "stripe past_due is not active" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(status: "past_due"))
    refute pay_subscription.active?
  end

  test "stripe incomplete is not active" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(status: "incomplete"))
    refute pay_subscription.active?
  end

  test "stripe change subscription quantity" do
    @pay_customer.update(processor_id: nil)
    @pay_customer.update_payment_method "pm_card_visa"
    subscription = @pay_customer.subscribe(name: "default", plan: "default")
    subscription.change_quantity(5)
    stripe_subscription = subscription.api_record
    assert_equal 5, stripe_subscription.items.first.quantity
    assert_equal 5, subscription.quantity
  end

  test "stripe change subscription quantity updates the subscription item" do
    pay_subscription = pay_subscriptions(:stripe)
    pay_subscription.update!(object: fake_stripe_subscription(id: "sub_1").to_hash)
    ::Stripe::Subscription.expects(:update).never
    ::Stripe::SubscriptionItem.expects(:update).with("si_1", {quantity: 3}, {}).returns(::Stripe::SubscriptionItem.construct_from(id: "si_1", object: "subscription_item", quantity: 3))

    pay_subscription.change_quantity(3)

    assert_equal 3, pay_subscription.reload.quantity
  end

  test "stripe change subscription quantity accepts a subscription_item_id" do
    pay_subscription = pay_subscriptions(:stripe)
    ::Stripe::SubscriptionItem.expects(:update).with("si_other", {quantity: 2, proration_behavior: "none"}, {}).returns(::Stripe::SubscriptionItem.construct_from(id: "si_other", object: "subscription_item", quantity: 2))

    pay_subscription.change_quantity(2, subscription_item_id: "si_other", proration_behavior: "none")

    assert_equal 2, pay_subscription.reload.quantity
  end

  test "cancel_now when scheduled for cancellation" do
    travel_to_cassette do
      @pay_customer.update(processor_id: nil)
      @pay_customer.update_payment_method "pm_card_visa"
      subscription = @pay_customer.subscribe(name: "default", plan: "default")
      subscription.cancel
      assert subscription.active?
      assert subscription.ends_at?
      subscription.cancel_now!
      # Travel since we froze time
      travel 1.minute
      refute subscription.active?
      assert subscription.ends_at.past?
    end
  end

  test "cancel_now when on trial" do
    travel_to_cassette do
      @pay_customer.update(processor_id: nil)
      @pay_customer.update_payment_method "pm_card_visa"
      subscription = @pay_customer.subscribe(name: "default", plan: "default", trial_period_days: 14)
      assert subscription.active?
      assert subscription.on_trial?
      subscription.cancel_now!
      travel 1.minute
      refute subscription.active?
      refute subscription.on_trial?
    end
  end

  test "sync Pay::Subscription retains custom name" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription, name: "Custom")
    assert_equal "Custom", pay_subscription.name
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    assert_equal "Custom", pay_subscription.name
  end

  test "sync stripe subscription by ID" do
    assert_difference "Pay::Subscription.count" do
      ::Stripe::Subscription.stubs(:retrieve).returns(fake_stripe_subscription)
      Pay::Stripe::Subscription.sync("123")
    end
  end

  test "sync stores subscription metadata" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    assert_equal({"license_id" => 1}, pay_subscription.metadata)
  end

  test "sync uses name from subscription metadata" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(metadata: {"pay_name" => "test-subscription"}))
    assert_equal "test-subscription", pay_subscription.name
  end

  test "sync stripe subscription ignores when customer is missing" do
    assert_no_difference "Pay::Subscription.count" do
      Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(customer: "missing"))
    end
  end

  test "sync stripe subscription sets created_at" do
    fake_subscription = fake_stripe_subscription(created: 1488987924)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_equal 1488987924, pay_subscription.created_at.to_i
  end

  test "sync stripe subscription sets current_period_start" do
    fake_subscription = fake_stripe_subscription
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_equal fake_subscription.items.first.current_period_start, pay_subscription.current_period_start.to_i
  end

  test "sync stripe subscription sets current_period_end" do
    fake_subscription = fake_stripe_subscription
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_equal 1488987924, pay_subscription.current_period_end.to_i
  end

  test "sync stripe subscription sets ends_at when canceling at period end" do
    fake_subscription = fake_stripe_subscription(cancel_at_period_end: true)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_not_nil pay_subscription.ends_at
  end

  test "sync stripe subscription sets ends_at when ended" do
    fake_subscription = fake_stripe_subscription(ended_at: 1488987924)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_equal 1488987924, pay_subscription.ends_at.to_i
  end

  test "sync stripe subscription has nil trial_ends_at without trial" do
    fake_subscription = fake_stripe_subscription(ended_at: 1488987924)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_nil pay_subscription.trial_ends_at
  end

  test "sync stripe subscription sets trial_ends_at with trial" do
    fake_subscription = fake_stripe_subscription(trial_end: 1488987924)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_equal 1488987924, pay_subscription.trial_ends_at.to_i
  end

  test "sync stripe subscription does not set trial_ends_at when subscription canceled after trial end" do
    fake_subscription = fake_stripe_subscription(trial_end: 1488987924, ended_at: 1650479887)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_equal 1488987924, pay_subscription.trial_ends_at.to_i
  end

  test "sync stripe subscription sets trial_ends_at to ended_at when subscription canceled before trial end" do
    fake_subscription = fake_stripe_subscription(trial_end: 1650479887, ended_at: 1488987924)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_equal 1488987924, pay_subscription.trial_ends_at.to_i
  end

  test "it will throw an error if the passed argument is not a string" do
    Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)

    assert_raises ArgumentError do
      @pay_customer.subscription.swap({invalid: :object})
    end
  end

  test "stripe resume on grace period" do
    travel_to_cassette do
      @pay_customer.update(processor_id: nil)
      @pay_customer.update_payment_method "pm_card_visa"
      subscription = @pay_customer.subscribe(name: "default", plan: "default")
      subscription.cancel
      assert_not_nil subscription.ends_at
      subscription.resume
      assert_nil subscription.ends_at
      assert_equal "active", subscription.status
    end
  end

  test "it will throw an error if subscription cannot be resumed" do
    Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)

    refute @pay_customer.subscription.resumable?
    assert_raises Pay::Error do
      @pay_customer.subscription.resume
    end
  end

  test "syncing multiple subscription items" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(items: {
      object: "list",
      data: [
        {
          id: "si_KjcLsWCXBgVRuU",
          object: "subscription_item",
          created: 1638904425,
          metadata: {},
          price: {
            id: "large-monthly"
          },
          quantity: 1
        },
        {
          id: "si_KjcL6OioIsoeuz",
          object: "subscription_item",
          created: 1638904425,
          metadata: {},
          price: {
            id: "personal"
          },
          quantity: 1
        }
      ],
      has_more: false,
      total_count: 2,
      url: "/v1/subscription_items?subscription=sub_1K496iKXBGcbgpbZSrTl9uTg"
    }))

    assert_equal 2, pay_subscription.stripe_object.items.data.length
  end

  test "subscription with a metered billing subscription item should have a quantity of 0" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription_with_metered_item)

    assert_equal 0, pay_subscription.quantity
  end

  test "#metered returns true if subscription has metered subscription items" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription_with_metered_item)
    assert pay_subscription.metered
  end

  test "#metered returns false if subscription does not have metered subscription items" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    refute pay_subscription.metered
  end

  test ".with_metered_items returns all subscriptions that have a metered billing subscription item associated" do
    assert_equal [pay_subscriptions(:stripe_with_items)], Pay::Subscription.metered.to_a
  end

  test "metered_subscription_item" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription_with_metered_item)
    assert_equal "metered", pay_subscription.metered_subscription_item.price.recurring.usage_type
  end

  test "stripe syncs pause_collection resumes_at to pause_resumes_at" do
    freeze_time
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "void", resumes_at: 30.days.from_now}, current_period_end: 1.day.from_now))
    assert_equal pay_subscription.pause_resumes_at, 30.days.from_now
  end

  test "stripe pause_behavior void sets pause_starts_at" do
    freeze_time
    # First sync the subscription, then sync as paused
    Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "void", resumes_at: nil}, items: {
      object: "list",
      data: [
        {
          id: "si_KjcLsWCXBgVRuU",
          object: "subscription_item",
          created: 1638904425,
          current_period_end: 1.day.from_now,
          metadata: {},
          price: {
            id: "large-monthly"
          },
          quantity: 1
        }
      ],
      has_more: false,
      total_count: 1,
      url: "/v1/subscription_items?subscription=sub_1K496iKXBGcbgpbZSrTl9uTg"
    }))
    assert_equal pay_subscription.pause_starts_at, 1.day.from_now
  end

  test "stripe pause_behavior mark_uncollectible does not set pause_starts_at" do
    # First sync the subscription, then sync as paused
    Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "mark_uncollectible", resumes_at: nil}, current_period_end: 1.day.from_now))
    assert_nil pay_subscription.pause_starts_at
  end

  test "stripe pause_behavior keep_as_draft does not set pause_starts_at" do
    # First sync the subscription, then sync as paused
    Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "keep_as_draft", resumes_at: nil}, current_period_end: 1.day.from_now))
    assert_nil pay_subscription.pause_starts_at
  end

  test "stripe pause_behavior void grace period" do
    # First sync the subscription, then sync as paused
    Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "void", resumes_at: nil}, items: {
      object: "list",
      data: [
        {
          id: "si_KjcLsWCXBgVRuU",
          object: "subscription_item",
          created: 1638904425,
          current_period_end: 1.day.from_now,
          metadata: {},
          price: {
            id: "large-monthly"
          },
          quantity: 1
        }
      ],
      has_more: false,
      total_count: 1,
      url: "/v1/subscription_items?subscription=sub_1K496iKXBGcbgpbZSrTl9uTg"
    }))
    assert pay_subscription.will_pause?
    refute pay_subscription.pause_active?
    assert pay_subscription.on_grace_period?
    assert pay_subscription.active?
  end

  test "stripe pause_behavior void after grace period" do
    # First sync the subscription, then sync as paused
    Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "void", resumes_at: nil}, current_period_end: 1.day.ago))
    refute pay_subscription.will_pause?
    assert pay_subscription.pause_active?
    refute pay_subscription.on_grace_period?
    refute pay_subscription.active?
  end

  test "stripe pause_behavior mark_uncollectible after grace period" do
    # First sync the subscription, then sync as paused
    Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "mark_uncollectible", resumes_at: nil}, current_period_end: 1.day.from_now))
    refute pay_subscription.on_grace_period?
    assert pay_subscription.active?
  end

  test "stripe pause_behavior keep_as_draft after grace period" do
    # First sync the subscription, then sync as paused
    Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "keep_as_draft", resumes_at: nil}, current_period_end: 1.day.from_now))
    refute pay_subscription.on_grace_period?
    assert pay_subscription.active?
  end

  test "stripe subscription syncs payment method association if string" do
    payment_method = pay_payment_methods(:one)
    Pay::Stripe::PaymentMethod.stubs(:sync).returns(payment_method)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(default_payment_method: "pm_1000"))
    assert_equal payment_method, pay_subscription.payment_method
  end

  test "stripe subscription syncs payment method association if object" do
    payment_method = pay_payment_methods(:one)
    Pay::Stripe::PaymentMethod.stubs(:sync).returns(payment_method)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(default_payment_method: fake_stripe_payment_method(id: "pm_1000")))
    assert_equal payment_method, pay_subscription.payment_method
  end

  test "stripe change subscription default payment method" do
    @pay_customer.update(processor_id: nil)
    @pay_customer.update_payment_method "pm_card_visa"
    subscription = @pay_customer.subscribe(name: "default", plan: "default")

    payment_method = ::Stripe::PaymentMethod.attach("pm_card_discover", {customer: @pay_customer.processor_id})
    subscription.update_payment_method payment_method.id
    assert_equal payment_method.id, subscription.payment_method_id
    assert_equal payment_method.id, subscription.api_record.default_payment_method.id

    subscription.update_payment_method ""
    assert_nil subscription.payment_method_id
    assert_nil subscription.api_record.default_payment_method
  end

  test "stripe pay_open_invoices pays the payment intent from each open invoice's payments" do
    pay_subscription = pay_subscriptions(:stripe)
    ::Stripe::Invoice.stubs(:list).returns(::Stripe::ListObject.construct_from(object: "list", has_more: false, data: [fake_stripe_open_invoice(payment_intent: "pi_1000")]))
    ::Stripe::PaymentIntent.stubs(:retrieve).with({id: "pi_1000"}, {}).returns(::Stripe::PaymentIntent.construct_from(id: "pi_1000", object: "payment_intent", status: "requires_confirmation"))
    ::Stripe::PaymentIntent.expects(:confirm).with("pi_1000", {}).returns(::Stripe::PaymentIntent.construct_from(id: "pi_1000", object: "payment_intent", status: "succeeded"))

    pay_subscription.pay_open_invoices
  end

  test "stripe pay_open_invoices skips open invoices without a payment" do
    pay_subscription = pay_subscriptions(:stripe)
    ::Stripe::Invoice.stubs(:list).returns(::Stripe::ListObject.construct_from(object: "list", has_more: false, data: [fake_stripe_open_invoice(payment_intent: nil)]))
    ::Stripe::PaymentIntent.expects(:retrieve).never
    ::Stripe::PaymentIntent.expects(:confirm).never

    pay_subscription.pay_open_invoices
  end

  test "stripe latest_payment returns the payment intent of the latest invoice" do
    pay_subscription = pay_subscriptions(:stripe)
    pay_subscription.api_record = fake_stripe_subscription(latest_invoice: fake_stripe_open_invoice(payment_intent: "pi_1000"))
    payment_intent = ::Stripe::PaymentIntent.construct_from(id: "pi_1000", object: "payment_intent", status: "succeeded")
    ::Stripe::PaymentIntent.expects(:retrieve).with({id: "pi_1000"}, {}).returns(payment_intent)

    assert_equal payment_intent, pay_subscription.latest_payment
  end

  test "stripe latest_payment is nil when the latest invoice has no payment" do
    pay_subscription = pay_subscriptions(:stripe)
    pay_subscription.api_record = fake_stripe_subscription(latest_invoice: fake_stripe_open_invoice(payment_intent: nil))
    ::Stripe::PaymentIntent.expects(:retrieve).never

    assert_nil pay_subscription.latest_payment
  end

  test "stripe sync passes the customer's stripe_account to the payment method sync" do
    @pay_customer.update!(stripe_account: "acct_123")
    Pay::Stripe::PaymentMethod.expects(:sync).with("pm_1000", stripe_account: "acct_123").returns(pay_payment_methods(:one))
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(default_payment_method: "pm_1000"))
    assert_equal "acct_123", pay_subscription.stripe_account
  end

  test "stripe sync! defaults to the subscription's stripe_account" do
    pay_subscription = pay_subscriptions(:stripe)
    pay_subscription.update!(stripe_account: "acct_123")
    Pay::Stripe::Subscription.expects(:sync).with("sub_1", stripe_account: "acct_123")
    pay_subscription.sync!
  end

  test "stripe sync_from_checkout_session passes the stripe_account through" do
    session = ::Stripe::Checkout::Session.construct_from(id: "cs_1", object: "checkout.session", subscription: "sub_1")
    ::Stripe::Checkout::Session.expects(:retrieve).with({id: "cs_1"}, {stripe_account: "acct_123"}).returns(session)
    Pay::Stripe::Subscription.expects(:sync).with("sub_1", stripe_account: "acct_123")
    Pay::Stripe::Subscription.sync_from_checkout_session("cs_1", stripe_account: "acct_123")
  end

  test "stripe resume keeps the trialing status returned by Stripe" do
    pay_subscription = pay_subscriptions(:stripe)
    pay_subscription.update!(status: "trialing", trial_ends_at: 5.days.from_now, ends_at: 3.days.from_now)
    ::Stripe::Subscription.expects(:update).returns(fake_stripe_subscription(id: "sub_1", status: "trialing"))

    pay_subscription.resume

    assert_nil pay_subscription.ends_at
    assert_equal "trialing", pay_subscription.status
  end

  test "stripe retry_failed_payment raises a clear error without a default payment method" do
    pay_subscription = pay_subscriptions(:stripe)
    pay_subscription.customer.payment_methods.update_all(default: false)
    ::Stripe::PaymentIntent.stubs(:retrieve).returns(::Stripe::PaymentIntent.construct_from(id: "pi_1000", object: "payment_intent", status: "requires_payment_method"))
    ::Stripe::PaymentIntent.expects(:confirm).never

    error = assert_raises(Pay::Stripe::Error) { pay_subscription.retry_failed_payment(payment_intent_id: "pi_1000") }
    assert_match(/no default payment method/, error.message)
  end

  test "stripe sync re-reads from the API when retrying without a passed object" do
    ::Stripe::Subscription.expects(:retrieve).twice.returns(fake_stripe_subscription)
    Pay::Stripe::Subscription.stubs(:create!).raises(ActiveRecord::RecordNotUnique.new("duplicate")).then.returns(pay_subscriptions(:stripe))
    Pay::Stripe::Subscription.stubs(:sleep)

    assert_equal pay_subscriptions(:stripe), Pay::Stripe::Subscription.sync("123")
  end

  test "stripe sync reuses a passed object when retrying" do
    ::Stripe::Subscription.expects(:retrieve).never
    Pay::Stripe::Subscription.stubs(:create!).raises(ActiveRecord::RecordNotUnique.new("duplicate")).then.returns(pay_subscriptions(:stripe))
    Pay::Stripe::Subscription.stubs(:sleep)

    assert_equal pay_subscriptions(:stripe), Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
  end

  test "stripe sync raises once retries are exhausted" do
    Pay::Stripe::Subscription.stubs(:create!).raises(ActiveRecord::RecordNotUnique.new("duplicate"))
    Pay::Stripe::Subscription.stubs(:sleep)

    assert_raises(ActiveRecord::RecordNotUnique) { Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription, retries: 1) }
  end

  private

  def fake_stripe_open_invoice(payment_intent:)
    payments = if payment_intent
      [{id: "inpay_1", object: "invoice_payment", status: "open", payment: {type: "payment_intent", payment_intent: payment_intent}}]
    else
      []
    end

    ::Stripe::Invoice.construct_from(id: "in_1000", object: "invoice", status: "open", payments: {object: "list", has_more: false, data: payments})
  end
end
