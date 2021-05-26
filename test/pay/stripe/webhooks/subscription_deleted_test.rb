require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionDeletedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/subscription_deleted_event.json")
  end

  test "syncs subscription" do
    Pay::Stripe::Subscription.expects(:sync)
    Pay::Stripe::Webhooks::SubscriptionDeleted.new.call(@event)
  end
end
