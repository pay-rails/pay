require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionCreatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("subscription.created")
  end

  test "subscription is created" do
    Pay::Stripe::Subscription.expects(:sync)
    Pay::Stripe::Webhooks::SubscriptionCreated.new.call(@event)
  end
end
