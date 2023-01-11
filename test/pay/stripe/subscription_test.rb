require "test_helper"

class Pay::Stripe::SubscriptionTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:stripe)
  end

  test "stripe past_due is not active" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(status: "past_due"))
    refute pay_subscription.active?
  end

  test "stripe incomplete is not active" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(status: "incomplete"))
    refute pay_subscription.active?
  end

  test "change stripe subscription quantity" do
    @pay_customer.processor_id = nil
    @pay_customer.payment_method_token = "pm_card_visa"
    subscription = @pay_customer.subscribe(name: "default", plan: "default")
    subscription.change_quantity(5)
    stripe_subscription = subscription.processor_subscription
    assert_equal 5, stripe_subscription.quantity
    assert_equal 5, subscription.quantity
  end

  test "change stripe subscription quantity with nil subscription items" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    pay_subscription.update!(subscription_items: nil)
    ::Stripe::Subscription.stubs(:update)
    assert pay_subscription.change_quantity(5)
  end

  test "change stripe subscription quantity with [] subscription items" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    pay_subscription.update!(subscription_items: [])
    ::Stripe::Subscription.stubs(:update)
    assert pay_subscription.change_quantity(5)
  end

  test "sync returns Pay::Subscription" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    assert pay_subscription.is_a?(Pay::Subscription)
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

  test "sync stripe subscription" do
    assert_difference "Pay::Subscription.count" do
      Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
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
    fake_subscription = fake_stripe_subscription(current_period_start: 1488987924)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_equal 1488987924, pay_subscription.current_period_start.to_i
  end

  test "sync stripe subscription sets current_period_end" do
    fake_subscription = fake_stripe_subscription(current_period_end: 1488987924)
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
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      @pay_customer.processor_id = nil
      @pay_customer.payment_method_token = "pm_card_visa"
      subscription = @pay_customer.subscribe(name: "default", plan: "default")
      subscription.cancel
      assert_not_nil subscription.ends_at
      subscription.resume
      assert_nil subscription.ends_at
      assert_equal "active", subscription.status
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

    assert_equal 2, pay_subscription.subscription_items.length
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
    assert_equal "metered", pay_subscription.metered_subscription_item.dig("price", "recurring", "usage_type")
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
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "void", resumes_at: nil}, current_period_end: 1.day.from_now))
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
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(pause_collection: {behavior: "void", resumes_at: nil}, current_period_end: 1.day.from_now))
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

  private

  def fake_stripe_subscription_with_metered_item
    fake_stripe_subscription(quantity: nil, items: {
      object: "list",
      data: [
        ::Stripe::Subscription.construct_from(
          id: "si_KjcLsWCXBgVRuU",
          object: "subscription_item",
          created: 1638904425,
          metadata: {},
          price: {
            id: "large-monthly",
            recurring: {
              aggregate_usage: "sum",
              interval: "month",
              interval_count: 1,
              usage_type: "metered"
            }
          }
        )
      ],
      has_more: false
    })
  end

  def fake_stripe_subscription(**values)
    values.reverse_merge!(
      id: "123",
      object: "subscription",
      application_fee_percent: nil,
      cancel_at: nil,
      cancel_at_period_end: false,
      created: 1466783124,
      current_period_end: 1488987924,
      current_period_start: 1486568724,
      customer: "cus_1234",
      ended_at: nil,
      latest_invoice: {
        id: "in_1000",
        status: "paid"
      },
      plan: {
        id: "default"
      },
      price: {
        id: "default"
      },
      quantity: 1,
      status: "active",
      trial_end: nil,
      metadata: {
        license_id: 1
      },
      pause_collection: nil,
      items: {
        object: "list",
        data: [
          {
            id: "si_1",
            object: "subscription_item",
            billing_threshold: nil,
            created: 1638904425,
            metadata: {},
            price: {
              id: "default",
              object: "price",
              active: true,
              aggregate_usage: nil,
              amount: 10000,
              amount_decimal: "10000",
              billing_scheme: "per_unit",
              created: 1571425606,
              currency: "usd",
              interval: "month",
              interval_count: 1,
              livemode: false,
              metadata: {},
              nickname: "Large Monthly",
              product: "prod_EYTX7RYhRjcwKD",
              usage_type: "licensed"
            },
            quantity: 1,
            subscription: "123",
            tax_rates: []
          }
        ],
        has_more: false,
        total_count: 1,
        url: "/v1/subscription_items?subscription=123"
      }
    )
    ::Stripe::Subscription.construct_from(values)
  end
end
