require "test_helper"

class Pay::Payment::Test < ActiveSupport::TestCase
  test "amount_with_currency" do
    fake_payment_intent = ActiveSupport::InheritableOptions.new(amount: 12_34, currency: "usd")
    assert_equal "$12.34", Pay::Payment.new(fake_payment_intent).amount_with_currency
  end

  test "from_id retrieves a payment intent on the connected account" do
    payment_intent = ::Stripe::PaymentIntent.construct_from(id: "pi_123", object: "payment_intent", status: "succeeded")
    ::Stripe::PaymentIntent.expects(:retrieve).with("pi_123", {stripe_account: "acct_123"}).returns(payment_intent)
    assert_equal payment_intent, Pay::Payment.from_id("pi_123", stripe_account: "acct_123").intent
  end

  test "from_id retrieves a setup intent on the connected account" do
    setup_intent = ::Stripe::SetupIntent.construct_from(id: "seti_123", object: "setup_intent", status: "succeeded")
    ::Stripe::SetupIntent.expects(:retrieve).with("seti_123", {stripe_account: "acct_123"}).returns(setup_intent)
    assert_equal setup_intent, Pay::Payment.from_id("seti_123", stripe_account: "acct_123").intent
  end

  test "from_id sends no stripe_account when none is given" do
    payment_intent = ::Stripe::PaymentIntent.construct_from(id: "pi_123", object: "payment_intent", status: "succeeded")
    ::Stripe::PaymentIntent.expects(:retrieve).with("pi_123", {}).returns(payment_intent)
    assert_equal payment_intent, Pay::Payment.from_id("pi_123").intent
  end

  test "from_id remembers the stripe_account it was retrieved with" do
    ::Stripe::PaymentIntent.stubs(:retrieve).returns(::Stripe::PaymentIntent.construct_from(id: "pi_123", object: "payment_intent"))
    assert_equal "acct_123", Pay::Payment.from_id("pi_123", stripe_account: "acct_123").stripe_account
    assert_nil Pay::Payment.from_id("pi_123").stripe_account
  end

  test "from_id wraps Stripe errors in Pay::Stripe::Error" do
    ::Stripe::PaymentIntent.stubs(:retrieve).raises(::Stripe::InvalidRequestError.new("No such payment_intent", "id"))
    assert_raises(Pay::Stripe::Error) { Pay::Payment.from_id("pi_missing") }
  end
end
