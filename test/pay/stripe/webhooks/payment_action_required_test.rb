require "test_helper"

class Pay::Stripe::Webhooks::PaymentActionRequiredTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("invoice.payment_action_required")

    # Create user and subscription
    @pay_customer = pay_customers(:stripe)
    @pay_customer.update(processor_id: @event.data.object.customer)
    @subscription = @pay_customer.subscriptions.create!(
      processor_id: @event.data.object.subscription,
      name: "default",
      processor_plan: "some-plan",
      status: "requires_action"
    )
  end

  test "it sends an email" do
    assert_enqueued_jobs 1 do
      Pay::Stripe::Webhooks::PaymentActionRequired.new.call(@event)
    end
  end

  test "ignores if subscription doesn't exist" do
    @subscription.destroy!
    assert_no_enqueued_jobs do
      Pay::Stripe::Webhooks::PaymentActionRequired.new.call(@event)
    end
  end
end
