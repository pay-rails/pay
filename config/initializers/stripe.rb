require 'stripe_event'

env         = Rails.env.to_sym
secrets     = Rails.application.secrets
credentials = Rails.application.credentials

Stripe.api_key             = secrets.dig(env, :stripe, :private_key)    || credentials.dig(env, :stripe, :private_key)
StripeEvent.signing_secret = secrets.dig(env, :stripe, :signing_secret) || credentials.dig(env, :stripe, :signing_secret)

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
  events.subscribe 'customer.subscription.deleted', Pay::Stripe::SubscriptionDeleted.new

  # If the plan, quantity, or trial ending date is updated on Stripe, we want to sync
  events.subscribe 'customer.subscription.updated', Pay::Stripe::SubscriptionUpdated.new

  # Monitor changes for customer's default card changing
  events.subscribe 'customer.updated', Pay::Stripe::CustomerUpdated.new

  # If a customer was deleted in Stripe, their subscriptions should be cancelled
  events.subscribe 'customer.deleted', Pay::Stripe::CustomerDeleted.new

  # If a customer's payment source was deleted in Stripe, we should update as well
  events.subscribe 'customer.source.deleted', Pay::Stripe::SourceDeleted.new
end
