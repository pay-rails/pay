require "test_helper"

class Pay::Braintree::Webhooks::SubscriptionCanceledTest < ActiveSupport::TestCase
  setup do
    @event = braintree_event "subscription_cancelled"
  end

  test "braintree syncs subscription on cancelled webhook" do
    Pay::Braintree::Subscription.expects(:sync)
    Pay::Braintree::Webhooks::SubscriptionCanceled.new.call(@event)
  end
end
