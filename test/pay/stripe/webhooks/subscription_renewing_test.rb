require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionRenewingTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("invoice.upcoming")
    @pay_customer = pay_customers(:stripe)
    @pay_customer.update(processor_id: @event.data.object.customer)
  end

  test "yearly subscription should receive renewal email" do
    ::Stripe::Price.expects(:retrieve).returns(fake_stripe_price(interval: "year"))

    create_stripe_subscription(processor_id: @event.data.object.parent.subscription_details.subscription)
    Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    assert_enqueued_emails 1
  end

  test "monthly subscription should not receive renewal email" do
    ::Stripe::Price.expects(:retrieve).returns(fake_stripe_price(interval: "month"))

    create_stripe_subscription(processor_id: @event.data.object.parent.subscription_details.subscription)
    assert_no_enqueued_emails do
      Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    end
  end

  test "missing subscription should not receive renewal email" do
    assert_no_enqueued_emails do
      create_stripe_subscription(processor_id: "does-not-exist")
      Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    end
  end
end
