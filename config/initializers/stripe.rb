require 'stripe_event'

Stripe.api_key = Rails.application.secrets.stripe_api_key

StripeEvent.configure do |events|
  # Listen to the charge event to make sure we get non-subscription
  # purchases as well. Invoice is only for subscriptions and manual creation
  # so it does not include individual charges.
  events.subscribe 'charge.succeeded', Pay::Stripe::ChargeSucceeded.new
  events.subscribe 'charge.refunded', Pay::Stripe::ChargeRefunded.new
end
