require "test_helper"

class Pay::Braintree::Webhooks::SubscriptionCanceledTest < ActiveSupport::TestCase
  setup do
    @event = braintree_event "subscription_cancelled"
  end

  test "it sets ends_at on the subscription" do
    pay_customer = pay_customers(:braintree)
    pay_customer.update(processor_id: @event.subscription.transactions.first.customer_details.id)
    subscription = pay_customer.subscriptions.create!(
      processor_id: @event.subscription.id,
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay::Braintree::Webhooks::SubscriptionCanceled.new.call(@event)
    assert subscription.reload.cancelled?
  end
end
