require "test_helper"

class Pay::Braintree::Webhooks::SubscriptionChargedSuccessfullyTest < ActiveSupport::TestCase
  setup do
    @event = braintree_event "braintree/subscription_charged_successfully"
  end

  test "it sets ends_at on the subscription" do
    user = User.create!(
      email: "gob@bluth.com",
      processor: :braintree,
      processor_id: @event.subscription.transactions.first.customer_details.id
    )

    user.subscriptions.create!(
      processor: :braintree,
      processor_id: @event.subscription.id,
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    assert_difference "user.charges.count" do
      Pay::Braintree::Webhooks::SubscriptionChargedSuccessfully.new.call(@event)
    end
  end
end
