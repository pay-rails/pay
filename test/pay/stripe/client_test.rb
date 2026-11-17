require "test_helper"

# These tests check the HTTP requests stripe-ruby actually sends, so they use WebMock stubs instead of a VCR cassette.
# With no cassette inserted, a request that doesn't match a stub fails the test (WebMock raises, or Stripe rejects the fake key).
class Pay::Stripe::ClientTest < ActiveSupport::TestCase
  setup do
    VCR.eject_cassette
  end

  teardown do
    Pay::Stripe.client_resolver = nil
  end

  test "client uses the global Stripe API key and context by default" do
    ::Stripe.config.stubs(:stripe_context).returns("ctx_123")

    stub_request(:get, "https://api.stripe.com/v1/payment_intents/pi_1")
      .with(headers: {"Authorization" => "Bearer #{::Stripe.api_key}", "Stripe-Context" => "ctx_123"})
      .to_return(body: {id: "pi_1", object: "payment_intent", status: "succeeded"}.to_json)

    assert_equal "pi_1", Pay::Payment.from_id("pi_1").id
  end

  test "client uses the global Stripe API base and version by default" do
    ::Stripe.config.stubs(:api_base).returns("https://stripe-mock.test")
    ::Stripe.config.stubs(:api_version).returns("2020-01-01")

    stub_request(:get, "https://stripe-mock.test/v1/payment_intents/pi_1")
      .with(headers: {"Stripe-Version" => "2020-01-01"})
      .to_return(body: {id: "pi_1", object: "payment_intent", status: "succeeded"}.to_json)

    assert_equal "pi_1", Pay::Payment.from_id("pi_1").id
  end

  test "client_resolver supplies the client, and objects it returns keep using that client's API key" do
    Pay::Stripe.client_resolver = -> { ::Stripe::StripeClient.new("sk_test_other_platform") }

    create = stub_request(:post, "https://api.stripe.com/v1/invoices")
      .with(headers: {"Authorization" => "Bearer sk_test_other_platform"})
      .to_return(body: {id: "in_1", object: "invoice", status: "draft"}.to_json)
    # Invoice#pay is called on the returned object rather than through the client
    pay = stub_request(:post, "https://api.stripe.com/v1/invoices/in_1/pay")
      .with(headers: {"Authorization" => "Bearer sk_test_other_platform"})
      .to_return(body: {id: "in_1", object: "invoice", status: "paid"}.to_json)

    assert_equal "paid", pay_customers(:stripe).invoice!.status
    assert_requested create
    assert_requested pay
  end

  test "connected account requests send the Stripe-Account header" do
    stub_request(:get, "https://api.stripe.com/v1/payment_intents/pi_1")
      .with(headers: {"Stripe-Account" => "acct_123"})
      .to_return(body: {id: "pi_1", object: "payment_intent", status: "succeeded"}.to_json)

    assert_equal "acct_123", Pay::Payment.from_id("pi_1", stripe_account: "acct_123").stripe_account
  end
end
