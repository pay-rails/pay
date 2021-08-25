require "test_helper"

class Pay::Braintree::Webhooks::SubscriptionTrialEndedTest < ActiveSupport::TestCase
  setup do
    @event = braintree_event "subscription_trial_ended"
  end

  test "updates subscription trial end" do
    pay_customer = pay_customers(:braintree)

    pay_subscription = pay_customer.subscriptions.create!(
      processor_id: @event.subscription.id,
      name: "default",
      processor_plan: "some-plan",
      status: "active",
      trial_ends_at: 14.days.from_now
    )

    freeze_time do
      Pay::Braintree::Webhooks::SubscriptionTrialEnded.new.call(@event)
      assert_equal Time.current, pay_subscription.reload.trial_ends_at
    end
  end
end
