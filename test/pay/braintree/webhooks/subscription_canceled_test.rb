require "test_helper"

class Pay::Braintree::Webhooks::SubscriptionCanceledTest < ActiveSupport::TestCase
  setup do
    @event = braintree_event "braintree/subscription_cancelled"
  end

  test "it sets ends_at on the subscription" do
    user = User.create!(
      email: "gob@bluth.com",
      processor: :braintree,
      processor_id: @event.subscription.transactions.first.customer_details.id
    )

    subscription = user.subscriptions.create!(
      processor: :braintree,
      processor_id: @event.subscription.id,
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay::Braintree::Webhooks::SubscriptionCanceled.new.call(@event)

    assert subscription.reload.cancelled?
  end
end
