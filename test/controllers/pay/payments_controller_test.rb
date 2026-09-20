require "test_helper"

module Pay
  class PaymentsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test "shows a payment on the platform account" do
      ::Stripe::PaymentIntent.expects(:retrieve).with("pi_123", {}).returns(fake_payment_intent)

      get payment_path("pi_123")

      assert_response :success
      assert_includes response.body, %(data-payment-intent-public-key-value="#{Pay::Stripe.public_key}")
      assert_includes response.body, %(data-payment-intent-stripe-account-value="")
      refute_includes response.body[response.body.index("<script")..], "<%"
    end

    test "shows a payment on a connected account" do
      ::Stripe::PaymentIntent.expects(:retrieve).with("pi_123", {stripe_account: "acct_123"}).returns(fake_payment_intent)

      get payment_path("pi_123", stripe_account: "acct_123")

      assert_response :success
      assert_includes response.body, %(data-payment-intent-stripe-account-value="acct_123")
    end

    test "back link keeps a same-site path with its query string" do
      ::Stripe::PaymentIntent.stubs(:retrieve).returns(fake_payment_intent)

      get payment_path("pi_123", back: "/billing?tab=invoices")

      assert_select "a[href=?]", "/billing?tab=invoices"
    end

    test "back link falls back to root for external or malformed URLs" do
      ::Stripe::PaymentIntent.stubs(:retrieve).returns(fake_payment_intent)

      get payment_path("pi_123", back: "https://evil.example.com/phish")
      assert_select "a[href=?]", "/"

      get payment_path("pi_123", back: "http://[bad")
      assert_response :success
      assert_select "a[href=?]", "/"
    end

    private

    def fake_payment_intent
      ::Stripe::PaymentIntent.construct_from(id: "pi_123", object: "payment_intent", amount: 10_00, currency: "usd", status: "requires_action", client_secret: "pi_123_secret", customer: "cus_123")
    end
  end
end
