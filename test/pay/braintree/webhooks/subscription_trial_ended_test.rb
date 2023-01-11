require "test_helper"

class Pay::Braintree::Webhooks::SubscriptionTrialEndedTest < ActiveSupport::TestCase
  setup do
    @event = braintree_event "subscription_trial_ended"
  end

  test "braintree syncs subscription on trial ended webhook" do
    Pay::Braintree::Subscription.expects(:sync)
    Pay::Braintree::Webhooks::SubscriptionCanceled.new.call(@event)
  end
end
