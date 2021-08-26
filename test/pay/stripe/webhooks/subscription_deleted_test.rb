require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionDeletedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("subscription.deleted")
  end

  test "syncs subscription" do
    Pay::Stripe::Subscription.expects(:sync)
    Pay::Stripe::Webhooks::SubscriptionDeleted.new.call(@event)
  end
end
