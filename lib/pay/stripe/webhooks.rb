require "stripe_event"
Dir[File.join(__dir__, "webhooks", "**", "*.rb")].each { |file| require file }

StripeEvent.configure do |events|
  # Listen to the charge event to make sure we get non-subscription
  # purchases as well. Invoice is only for subscriptions and manual creation
  # so it does not include individual charges.
  events.subscribe "charge.succeeded", Pay::Stripe::Webhooks::ChargeSucceeded.new
  events.subscribe "charge.refunded", Pay::Stripe::Webhooks::ChargeRefunded.new

  # Warn user of upcoming charges for their subscription. This is handy for
  # notifying annual users their subscription will renew shortly.
  # This probably should be ignored for monthly subscriptions.
  events.subscribe "invoice.upcoming", Pay::Stripe::Webhooks::SubscriptionRenewing.new

  # Payment action is required to process an invoice
  events.subscribe "invoice.payment_action_required", Pay::Stripe::Webhooks::PaymentActionRequired.new

  # If a subscription is manually created on Stripe, we want to sync
  events.subscribe "customer.subscription.created", Pay::Stripe::Webhooks::SubscriptionCreated.new

  # If the plan, quantity, or trial ending date is updated on Stripe, we want to sync
  events.subscribe "customer.subscription.updated", Pay::Stripe::Webhooks::SubscriptionUpdated.new

  # When a customers subscription is canceled, we want to update our records
  events.subscribe "customer.subscription.deleted", Pay::Stripe::Webhooks::SubscriptionDeleted.new

  # Monitor changes for customer's default card changing
  events.subscribe "customer.updated", Pay::Stripe::Webhooks::CustomerUpdated.new

  # If a customer was deleted in Stripe, their subscriptions should be cancelled
  events.subscribe "customer.deleted", Pay::Stripe::Webhooks::CustomerDeleted.new

  # If a customer's payment source was deleted in Stripe, we should update as well
  events.subscribe "payment_method.attached", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
  events.subscribe "payment_method.updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
  events.subscribe "payment_method.card_automatically_updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
  events.subscribe "payment_method.detached", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
end
