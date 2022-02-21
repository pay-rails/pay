require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("subscription.updated")
    @pay_customer = pay_customers(:stripe)
    @pay_customer.update(processor_id: @event.data.object.customer)
  end

  test "nothing happens if a owner can't be found" do
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription
    Pay::Subscription.any_instance.expects(:update).never
    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
  end

  test "subscription is updated" do
    subscription = @pay_customer.subscriptions.create!(processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(quantity: 2, ended_at: nil, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)

    subscription.reload
    assert_equal 2, subscription.quantity
    assert_equal "FFBEGINNER_00000000000000", subscription.processor_plan
    assert_equal Time.at(@event.data.object.trial_end), subscription.trial_ends_at
    assert_nil subscription.ends_at
  end

  test "subscription is updated with cancel_at_period_end = true and on_trial? = false" do
    subscription = @pay_customer.subscriptions.create!(processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(cancel_at_period_end: true, current_period_end: @event.data.object.current_period_end, ended_at: nil, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal Time.at(@event.data.object.current_period_end), subscription.reload.ends_at
  end

  test "subscription is updated with cancel_at_period_end = true and on_trial? = true" do
    subscription = @pay_customer.subscriptions.create!(processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    trial_end = 3.days.from_now.beginning_of_day
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(cancel_at_period_end: true, current_period_end: trial_end, ended_at: nil, trial_end: trial_end, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)

    assert_equal 3.days.from_now.beginning_of_day, subscription.reload.ends_at
  end

  test "subscription is updated with ended_at set" do
    subscription = @pay_customer.subscriptions.create!(processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    sub_end = 3.days.ago.beginning_of_day
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(cancel_at_period_end: false, ended_at: sub_end, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal sub_end, subscription.reload.ends_at
  end

  test "subscription is updated with cancel_at set" do
    subscription = @pay_customer.subscriptions.create!(processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active")
    sub_cancel = 3.days.ago.beginning_of_day
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(ended_at: nil, cancel_at: sub_cancel)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_equal sub_cancel, subscription.reload.ends_at
  end

  test "subscription was canceled, now renewed" do
    subscription = @pay_customer.subscriptions.create!(processor_id: @event.data.object.id, name: "default", processor_plan: "some-plan", status: "active", ends_at: Time.now)
    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(cancel_at_period_end: false, ended_at: nil, cancel_at: nil)

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
    assert_nil subscription.reload.ends_at
  end

  def fake_stripe_subscription(**values)
    values.reverse_merge!(@event.data.object.to_hash)
    ::Stripe::Subscription.construct_from(values)
  end

  test "subscription with prices is updated" do
    # @user = User.create!(email: "gob@bluth.com")
    # @user.set_payment_processor :stripe
    # @user.payment_processor.processor_id = @event.data.object.customer

    subscription = @pay_customer.subscriptions.create!(
      processor_id: @event.data.object.id,
      name: "default",
      processor_plan: "some-plan",
      status: "active",
      subscription_items_attributes: [
        {
          processor_id: "si_00000000000001",
          processor_price: "price_000000000000000000000001",
          quantity: 1
        },
        {
          processor_id: "si_00000000000002",
          processor_price: "price_000000000000000000000002",
          quantity: 1
        }
      ]
    )

    ::Stripe::Subscription.stubs(:retrieve).returns fake_stripe_subscription(
      processor_id: "sub_00000000000000",
      items: {
        data: [
          {
            id: "si_00000000000003",
            price: {
              id: "price_000000000000000000000003"
            },
            quantity: 2
          }
        ]
      }
    )

    Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(@event)
    subscription.reload

    assert_equal 1, subscription.subscription_items.length
    subscription = subscription.subscription_items.first
    assert_equal "price_000000000000000000000003", subscription.processor_price
    assert_equal 2, subscription.quantity
  end
end
