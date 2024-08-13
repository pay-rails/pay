require "test_helper"

class Pay::Webhook::Test < ActiveSupport::TestCase
  test "rehydrates a Paddle Classic event" do
    pay_webhook = Pay::Webhook.create processor: :paddle_classic, event_type: :example, event: json_fixture("paddle_classic/subscription_payment_succeeded")
    event = pay_webhook.rehydrated_event
    assert_equal OpenStruct, event.class
    assert_equal "visa", event.payment_method.card_type
  end

  test "rehydrates a Stripe event" do
    pay_webhook = Pay::Webhook.create processor: :stripe, event_type: :example, event: json_fixture("stripe/customer.updated")
    event = pay_webhook.rehydrated_event
    assert_equal ::Stripe::Event, event.class
    assert_equal "pm_1000", event.previous_attributes.invoice_settings.default_payment_method
  end

  test "rehydrates a Braintree event" do
    pay_webhook = Pay::Webhook.create processor: :braintree, event_type: :example, event: json_fixture("braintree/subscription_charged_successfully")
    event = pay_webhook.rehydrated_event
    assert_equal ::Braintree::WebhookNotification, event.class
    assert_equal "f6rnpm", event.subscription.id
  end
end
