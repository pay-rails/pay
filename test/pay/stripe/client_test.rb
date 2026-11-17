require "test_helper"

# These tests check the HTTP requests stripe-ruby actually sends, so they use WebMock instead of VCR
class Pay::Stripe::ClientTest < ActiveSupport::TestCase
  teardown do
    Pay::Stripe.client_resolver = nil
  end

  test "client uses the global Stripe API key and context by default" do
    original_context = ::Stripe.config.stripe_context
    ::Stripe.config.stripe_context = "ctx_123"

    without_vcr do
      stub_request(:get, "https://api.stripe.com/v1/payment_intents/pi_1")
        .with(headers: {"Authorization" => "Bearer #{::Stripe.api_key}", "Stripe-Context" => "ctx_123"})
        .to_return(body: {id: "pi_1", object: "payment_intent", status: "succeeded"}.to_json)

      assert_equal "pi_1", Pay::Payment.from_id("pi_1").id
    end
  ensure
    ::Stripe.config.stripe_context = original_context
  end

  test "client_resolver supplies the client, and objects it returns keep using that client's API key" do
    Pay::Stripe.client_resolver = -> { ::Stripe::StripeClient.new("sk_test_other_platform") }

    without_vcr do
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
  end

  test "connected account requests send the Stripe-Account header" do
    without_vcr do
      stub_request(:get, "https://api.stripe.com/v1/payment_intents/pi_1")
        .with(headers: {"Stripe-Account" => "acct_123"})
        .to_return(body: {id: "pi_1", object: "payment_intent", status: "succeeded"}.to_json)

      assert_equal "acct_123", Pay::Payment.from_id("pi_1", stripe_account: "acct_123").stripe_account
    end
  end

  private

  # A request that doesn't match a stub fails the test (WebMock raises, or Stripe rejects the fake key)
  def without_vcr
    cassette = VCR.eject_cassette
    VCR.turned_off { yield }
  ensure
    WebMock.reset!
    # The suite's teardown ejects a cassette, so put this test's back
    VCR.insert_cassette(cassette.name, allow_unused_http_interactions: false) if cassette
  end
end
