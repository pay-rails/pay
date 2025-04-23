require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionRenewingTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("invoice.upcoming")
    @invoice = @event.data.object
    @pay_customer = pay_customers(:stripe)
    @pay_customer.update(processor_id: @event.data.object.customer)
  end

  test "yearly subscription should receive renewal email" do
    ::Stripe::Price.expects(:retrieve).returns(::Stripe::Price.construct_from(
      id: "price_1234",
      object: "price",
      active: true,
      billing_scheme: "per_unit",
      created: 1673394102,
      currency: "usd",
      custom_unit_amount: nil,
      livemode: false,
      lookup_key: nil,
      metadata: {},
      nickname: nil,
      product: "prod_1234",
      recurring: {
        aggregate_usage: nil,
        interval: "year",
        interval_count: 1,
        meter: nil,
        trial_period_days: nil,
        usage_type: "licensed"
      },
      tax_behavior: "exclusive",
      tiers_mode: nil,
      transform_quantity: nil,
      type: "recurring",
      unit_amount: 1900,
      unit_amount_decimal: "1900"
    ))

    create_subscription(processor_id: @event.data.object.parent.subscription_details.subscription)
    Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    assert_enqueued_emails 1
  end

  test "monthly subscription should not receive renewal email" do
    ::Stripe::Price.expects(:retrieve).returns(::Stripe::Price.construct_from(
      id: "price_1234",
      object: "price",
      active: true,
      billing_scheme: "per_unit",
      created: 1673394102,
      currency: "usd",
      custom_unit_amount: nil,
      livemode: false,
      lookup_key: nil,
      metadata: {},
      nickname: nil,
      product: "prod_1234",
      recurring: {
        aggregate_usage: nil,
        interval: "month",
        interval_count: 1,
        meter: nil,
        trial_period_days: nil,
        usage_type: "licensed"
      },
      tax_behavior: "exclusive",
      tiers_mode: nil,
      transform_quantity: nil,
      type: "recurring",
      unit_amount: 1900,
      unit_amount_decimal: "1900"
    ))

    create_subscription(processor_id: @event.data.object.parent.subscription_details.subscription)
    assert_no_enqueued_emails do
      Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    end
  end

  test "missing subscription should not receive renewal email" do
    assert_no_enqueued_emails do
      create_subscription(processor_id: "does-not-exist")
      Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    end
  end

  private

  def create_subscription(processor_id:)
    @pay_customer.subscriptions.create!(processor_id: processor_id, name: "default", processor_plan: "some-plan", status: "active")
  end
end
