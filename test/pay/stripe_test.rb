require "test_helper"

class Pay::Stripe::Test < ActiveSupport::TestCase
  test "finds API keys from env" do
    ENV["STRIPE_PUBLIC_KEY"] = "public"
    ENV["STRIPE_PRIVATE_KEY"] = "private"
    ENV["STRIPE_SIGNING_SECRET"] = "secret"

    assert_equal "public", Pay::Stripe.public_key
    assert_equal "private", Pay::Stripe.private_key
    assert_equal "secret", Pay::Stripe.signing_secret

    ENV.delete("STRIPE_PUBLIC_KEY")
    ENV.delete("STRIPE_PRIVATE_KEY")
    ENV.delete("STRIPE_SIGNING_SECRET")
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

  test "it reads Rails secrets for Rails versions below (<) 7.2.0" do
    Rails.application.expects(:credentials).twice.returns(nil)
    Rails.application.expects(:secrets).twice.returns({stripe: {public_key: "stripe_pk_from_secrets"}})
    Rails.expects(:gem_version).twice.returns(Gem::Version.new("7.0.6"))

    assert_equal "stripe_pk_from_secrets", Pay::Stripe.public_key
  end

  test "it doesn't read Rails secrets for Rails versions above (>=) 7.2.0" do
    Rails.application.expects(:credentials).twice.returns({stripe: {public_key: "stripe_pk_from_credentials"}})
    Rails.application.expects(:secrets).never.returns({stripe: {public_key: "stripe_pk_from_secrets"}})
    Rails.expects(:gem_version).returns(Gem::Version.new("7.2.0"))

    assert_equal "stripe_pk_from_credentials", Pay::Stripe.public_key
  end
end
