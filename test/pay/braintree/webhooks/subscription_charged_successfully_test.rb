require "test_helper"

class Pay::Braintree::Webhooks::SubscriptionChargedSuccessfullyTest < ActiveSupport::TestCase
  setup do
    @event = braintree_event "subscription_charged_successfully"
  end

  test "it sets ends_at on the subscription" do
    pay_customer = pay_customers(:braintree)
    pay_customer.update(processor_id: @event.subscription.transactions.first.customer_details.id)

    pay_subscription = pay_customer.pay_subscriptions.create!(
      processor_id: @event.subscription.id,
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    assert_difference "pay_customer.pay_charges.count" do
      Pay::Braintree::Webhooks::SubscriptionChargedSuccessfully.new.call(@event)
    end

    assert_equal pay_subscription, Pay::Charge.find_by!(processor_id: @event.subscription.transactions.first.id).subscription
  end
end
