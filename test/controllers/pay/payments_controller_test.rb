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
      assert_includes response.body, "Stripe('#{Pay::Stripe.public_key}', {})"
    end

    test "shows a payment on a connected account" do
      ::Stripe::PaymentIntent.expects(:retrieve).with("pi_123", {stripe_account: "acct_123"}).returns(fake_payment_intent)

      get payment_path("pi_123", stripe_account: "acct_123")

      assert_response :success
      assert_includes response.body, %(Stripe('#{Pay::Stripe.public_key}', {"stripeAccount":"acct_123"}))
    end

    private

    def fake_payment_intent
      ::Stripe::PaymentIntent.construct_from(id: "pi_123", object: "payment_intent", amount: 10_00, currency: "usd", status: "requires_action", client_secret: "pi_123_secret", customer: "cus_123")
    end
  end
end
