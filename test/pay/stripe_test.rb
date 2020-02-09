require "test_helper"

class Pay::Stripe::Test < ActiveSupport::TestCase
  test "finds API keys from env" do
    ENV["STRIPE_PUBLIC_KEY"] = "public"
    ENV["STRIPE_PRIVATE_KEY"] = "private"
    ENV["STRIPE_SIGNING_SECRET"] = "secret"

    assert_equal "public", Pay::Stripe.public_key
    assert_equal "private", Pay::Stripe.private_key
    assert_equal "secret", Pay::Stripe.signing_secret
  end
end
