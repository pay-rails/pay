require "test_helper"

class Pay::Subscription::Test < ActiveSupport::TestCase
  setup do
    @subscription = Pay.subscription_model.new processor: :invalid
  end

  test "braintree?" do
    refute @subscription.braintree?
  end

  test "stripe?" do
    refute @subscription.stripe?
  end

  test "paddle?" do
    refute @subscription.paddle?
  end

  test "braintree scope" do
    assert Pay.subscription_model.braintree.is_a?(ActiveRecord::Relation)
  end

  test "stripe scope" do
    assert Pay.subscription_model.stripe.is_a?(ActiveRecord::Relation)
  end

  test "paddle scope" do
    assert Pay.subscription_model.paddle.is_a?(ActiveRecord::Relation)
  end
end
