require 'stripe_event'

Stripe.api_key             = Rails.application.secrets.stripe_api_key || Rails.application.credentials.dig(Rails.env, :stripe, :private_key)
StripeEvent.signing_secret = Rails.application.secrets.stripe_signing_secret || Rails.application.credentials.dig(Rails.env, :stripe, :signing_secret)

StripeEvent.configure do |events|
  # Listen to the charge event to make sure we get non-subscription
  # purchases as well. Invoice is only for subscriptions and manual creation
  # so it does not include individual charges.
  events.subscribe 'charge.succeeded', Pay::Stripe::ChargeSucceeded.new
  events.subscribe 'charge.refunded', Pay::Stripe::ChargeRefunded.new

  # Warn user of upcoming charges for their subscription. This is handy for
  # notifying annual users their subscription will renew shortly.
  # This probably should be ignored for monthly subscriptions.
  events.subscribe 'invoice.upcoming', Pay::Stripe::SubscriptionRenewing.new

  # When a customers subscription is canceled, we want to update our records
  events.subscribe 'customer.subscription.deleted', Pay::Stripe::SubscriptionCanceled.new
end
