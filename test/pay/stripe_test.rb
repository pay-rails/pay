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

  test "can generate a client_reference_id for a model" do
    user = users(:none)
    assert_equal "User/#{user.id}", Pay::Stripe.to_client_reference_id(user)
  end

  test "raises an error for client_reference_id if the object does not use Pay" do
    assert_raises ArgumentError do
      Pay::Stripe.to_client_reference_id("not-a-user-instance")
    end
  end

  test "can find a record by client_reference_id" do
    user = users(:none)
    assert_equal user, Pay::Stripe.find_by_client_reference_id("User/#{user.id}")
  end

  test "returns nil if record not found by client_reference_id" do
    assert_nil Pay::Stripe.find_by_client_reference_id("User/9999")
  end

  test "returns nil if client_reference_id is not an allowed class" do
    assert_nil Pay::Stripe.find_by_client_reference_id("Secret::Agent::Man/9999")
  end

  test "env ignores Stripe secrets when not defined" do
    Rails.stub(:application, nil) do
      assert_nil Pay::Stripe.send(:secrets)
    end
  end

  test "env ignores Stripe credentials when not defined" do
    Rails.stub(:application, nil) do
      assert_nil Pay::Stripe.send(:credentials)
    end
  end
end
