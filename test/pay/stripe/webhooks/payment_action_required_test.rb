require "test_helper"

class Pay::Stripe::Webhooks::PaymentActionRequiredTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("invoice.payment_action_required")

    # Create user and subscription
    pay_customers(:stripe).update!(processor_id: @event.data.object.customer)
  end

  test "it sends an email" do
    Pay::Stripe::Subscription.sync @event.data.object.subscription, object: fake_stripe_subscription(id: @event.data.object.subscription, customer: @event.data.object.customer, status: :past_due)

    assert_enqueued_jobs 1 do
      Pay::Stripe::Webhooks::PaymentActionRequired.new.call(@event)
    end
  end

  test "skips email if subscription is incomplete" do
    Pay::Stripe::Subscription.sync @event.data.object.subscription, object: fake_stripe_subscription(id: @event.data.object.subscription, customer: @event.data.object.customer, status: :incomplete)

    assert_no_enqueued_jobs do
      Pay::Stripe::Webhooks::PaymentActionRequired.new.call(@event)
    end
  end
end
