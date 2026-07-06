require "test_helper"

class Pay::Stripe::WebhooksTest < ActiveSupport::TestCase
  test "subscribes to payment_method.automatically_updated" do
    assert Pay::Webhooks.delegator.listening?("stripe.payment_method.automatically_updated")
  end

  test "subscribes to payment_method.card_automatically_updated" do
    assert Pay::Webhooks.delegator.listening?("stripe.payment_method.card_automatically_updated")
  end
end
