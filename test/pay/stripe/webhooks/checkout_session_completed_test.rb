require "test_helper"

class Pay::Stripe::Webhooks::CheckoutSessionCompletedTest < ActiveSupport::TestCase
  test "creates Pay::Customer if client_reference_id present and valid" do
    client_reference_id = Pay::Stripe.to_client_reference_id(users(:none))
    event = stripe_event("checkout.session.completed", overrides: {"object" => {"client_reference_id" => client_reference_id}})
    Pay::Stripe::Subscription.expects(:sync)
    assert_difference "Pay::Customer.count" do
      Pay::Stripe::Webhooks::CheckoutSessionCompleted.new.call(event)
    end
  end

  test "handles client_reference_id if present but not valid" do
    event = stripe_event("checkout.session.completed", overrides: {"object" => {"client_reference_id" => "invalid"}})
    Pay::Stripe::Subscription.expects(:sync)
    assert_no_difference "Pay::Customer.count" do
      Pay::Stripe::Webhooks::CheckoutSessionCompleted.new.call(event)
    end
  end

  test "checkout session completed syncs latest charge" do
    event = stripe_event("checkout.session.completed", overrides: {"object" => {"payment_intent" => "pi_1234", "latest_charge" => "ch_1234", "subscription" => nil}})
    ::Stripe::PaymentIntent.expects(:retrieve).returns(OpenStruct.new(id: "pi_1234", latest_charge: OpenStruct.new(id: "ch_1234")))
    Pay::Stripe::Charge.expects(:sync)
    assert_no_difference "Pay::Customer.count" do
      Pay::Stripe::Webhooks::CheckoutSessionCompleted.new.call(event)
    end
  end
end
