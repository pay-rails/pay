require "test_helper"

class Pay::Stripe::SubscriptionTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:stripe)
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

  test "sync stripe subscription ignores when customer is missing" do
    assert_no_difference "Pay::Subscription.count" do
      Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription(customer: "missing"))
    end
  end

  test "sync stripe subscription sets ends_at when canceling at period end" do
    fake_subscription = fake_stripe_subscription(cancel_at_period_end: true)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_not_nil pay_subscription.ends_at
  end

  test "sync stripe subscription sets ends_at when ended" do
    fake_subscription = fake_stripe_subscription(ended_at: 1488987924)
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_subscription)
    assert_not_nil pay_subscription.ends_at
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

  test "multiple subscription items" do
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

    pay_subscription
  end

  private

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
      latest_invoice: "in_1000",
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
