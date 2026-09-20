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
    ::Stripe::PaymentIntent.expects(:retrieve).returns(::Stripe::PaymentIntent.construct_from(id: "pi_1234", latest_charge: ::Stripe::Charge.construct_from(id: "ch_1234")))
    Pay::Stripe::Charge.expects(:sync)
    assert_no_difference "Pay::Customer.count" do
      Pay::Stripe::Webhooks::CheckoutSessionCompleted.new.call(event)
    end
  end

  test "does not clear an existing processor_id when the session has no customer" do
    pay_customer = pay_customers(:stripe)
    client_reference_id = Pay::Stripe.to_client_reference_id(pay_customer.owner)
    event = stripe_event("checkout.session.completed", overrides: {"object" => {"client_reference_id" => client_reference_id, "customer" => nil, "subscription" => nil}})
    assert_no_difference "Pay::Customer.count" do
      Pay::Stripe::Webhooks::CheckoutSessionCompleted.new.call(event)
    end
    assert_equal "cus_1234", pay_customer.reload.processor_id
  end

  test "associates the owner with the connected account from the event" do
    client_reference_id = Pay::Stripe.to_client_reference_id(users(:none))
    event = stripe_event("checkout.session.completed", overrides: {"object" => {"client_reference_id" => client_reference_id}}, account: "acct_123")
    Pay::Stripe::Subscription.expects(:sync).with(event.data.object.subscription, stripe_account: "acct_123")
    assert_difference "Pay::Customer.count" do
      Pay::Stripe::Webhooks::CheckoutSessionCompleted.new.call(event)
    end
    pay_customer = users(:none).pay_customers.last
    assert_equal event.data.object.customer, pay_customer.processor_id
    assert_equal "acct_123", pay_customer.stripe_account
  end
end
