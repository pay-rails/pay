require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionRenewingTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("invoice.upcoming")
    @pay_customer = pay_customers(:stripe)
    @pay_customer.update(processor_id: @event.data.object.customer)
  end

  test "yearly subscription should receive renewal email" do
    @event.data.object.lines.data.first.price.recurring.interval = "year"

    create_subscription(processor_id: @event.data.object.subscription)
    Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    assert_enqueued_emails 1
  end

  test "monthly subscription should not receive renewal email" do
    @event.data.object.lines.data.first.price.recurring.interval = "month"

    create_subscription(processor_id: @event.data.object.subscription)
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

  test "should prevent delivery" do
    Pay.emails.subscription_renewing=false

    @event.data.object.lines.data.first.price.recurring.interval = "year"
    create_subscription(processor_id: @event.data.object.subscription)

    assert_no_enqueued_emails do
      Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    end
  end

  private

  def create_subscription(processor_id:)
    @pay_customer.subscriptions.create!(processor_id: processor_id, name: "default", processor_plan: "some-plan", status: "active")
  end
end
