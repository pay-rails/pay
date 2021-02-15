module Pay
  module Stripe
    include Env

    extend self

    def setup
      ::Stripe.api_key = private_key
      ::Stripe.api_version = "2020-08-27"

      # Used by Stripe to identify Pay for support
      ::Stripe.set_app_info("PayRails", partner_id: "pp_partner_IqhY0UExnJYLxg", version: Pay::VERSION, url: "https://github.com/pay-rails/pay")

      Pay.charge_model.include Pay::Stripe::Charge
      Pay.subscription_model.include Pay::Stripe::Subscription

      configure_webhooks
    end

    def public_key
      find_value_by_name(:stripe, :public_key)
    end

    def private_key
      find_value_by_name(:stripe, :private_key)
    end

    def signing_secret
      find_value_by_name(:stripe, :signing_secret)
    end

    def configure_webhooks
      Pay::Webhooks.configure do |events|
        # Listen to the charge event to make sure we get non-subscription
        # purchases as well. Invoice is only for subscriptions and manual creation
        # so it does not include individual charges.
        events.subscribe "stripe.charge.succeeded", Pay::Stripe::Webhooks::ChargeSucceeded.new
        events.subscribe "stripe.charge.refunded", Pay::Stripe::Webhooks::ChargeRefunded.new

        # Warn user of upcoming charges for their subscription. This is handy for
        # notifying annual users their subscription will renew shortly.
        # This probably should be ignored for monthly subscriptions.
        events.subscribe "stripe.invoice.upcoming", Pay::Stripe::Webhooks::SubscriptionRenewing.new

        # Payment action is required to process an invoice
        events.subscribe "stripe.invoice.payment_action_required", Pay::Stripe::Webhooks::PaymentActionRequired.new

        # If a subscription is manually created on Stripe, we want to sync
        events.subscribe "stripe.customer.subscription.created", Pay::Stripe::Webhooks::SubscriptionCreated.new

        # If the plan, quantity, or trial ending date is updated on Stripe, we want to sync
        events.subscribe "stripe.customer.subscription.updated", Pay::Stripe::Webhooks::SubscriptionUpdated.new

        # When a customers subscription is canceled, we want to update our records
        events.subscribe "stripe.customer.subscription.deleted", Pay::Stripe::Webhooks::SubscriptionDeleted.new

        # Monitor changes for customer's default card changing
        events.subscribe "stripe.customer.updated", Pay::Stripe::Webhooks::CustomerUpdated.new

        # If a customer was deleted in Stripe, their subscriptions should be cancelled
        events.subscribe "stripe.customer.deleted", Pay::Stripe::Webhooks::CustomerDeleted.new

        # If a customer's payment source was deleted in Stripe, we should update as well
        events.subscribe "stripe.payment_method.attached", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        events.subscribe "stripe.payment_method.updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        events.subscribe "stripe.payment_method.card_automatically_updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        events.subscribe "stripe.payment_method.detached", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
      end
    end
  end
end
