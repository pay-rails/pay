require "test_helper"

class Pay::Stripe::Webhooks::CheckoutSessionCompletedTest < ActiveSupport::TestCase
  test "creates Pay::Customer if client_reference_id present and valid" do
    event = stripe_event("checkout.session.completed", overrides: { "object" => { "client_reference_id" => users(:none).to_sgid.to_s }})
    Pay::Stripe::Subscription.expects(:sync)
    assert_difference "Pay::Customer.count" do
      Pay::Stripe::Webhooks::CheckoutSessionCompleted.new.call(event)
    end
  end

  test "handles client_reference_id if present but not valid" do
    event = stripe_event("checkout.session.completed", overrides: { object: { client_reference_id: users(:none).to_sgid.to_s }})
    Pay::Stripe::Subscription.expects(:sync)
    assert_no_difference "Pay::Customer.count" do
      Pay::Stripe::Webhooks::CheckoutSessionCompleted.new.call(event)
    end
  end
end
