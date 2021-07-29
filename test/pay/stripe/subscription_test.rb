require "test_helper"

class Pay::Stripe::SubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: "cus_1234")
  end

  test "change stripe subscription quantity" do
    @user.processor_id = nil
    @user.card_token = "pm_card_visa"
    subscription = @user.subscribe(name: "default", plan: "default")
    subscription.change_quantity(5)
    stripe_subscription = subscription.processor_subscription
    assert_equal 5, stripe_subscription.quantity
    assert_equal 5, subscription.quantity
  end

  test "sync returns Pay::Subscription" do
    pay_subscription = Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
    assert pay_subscription.is_a?(Pay::Subscription)
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

  test "sync stripe subscription ignores when customer is missing" do
    @user.destroy
    assert_no_difference "Pay::Subscription.count" do
      Pay::Stripe::Subscription.sync("123", object: fake_stripe_subscription)
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
      @user.subscription.swap({invalid: :object})
    end
  end

  private

  def fake_stripe_subscription(**values)
    values.reverse_merge!(
      id: "123",
      application_fee_percent: nil,
      cancel_at: nil,
      cancel_at_period_end: false,
      created: 1466783124,
      current_period_end: 1488987924,
      current_period_start: 1486568724,
      customer: "cus_1234",
      ended_at: nil,
      plan: {
        id: "default"
      },
      quantity: 1,
      status: "active",
      trial_end: nil
    )
    ::Stripe::Subscription.construct_from(values)
  end
end
