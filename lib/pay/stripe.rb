module Pay
  module Stripe
    autoload :Billable, "pay/stripe/billable"
    autoload :Charge, "pay/stripe/charge"
    autoload :Error, "pay/stripe/error"
    autoload :Merchant, "pay/stripe/merchant"
    autoload :PaymentMethod, "pay/stripe/payment_method"
    autoload :Subscription, "pay/stripe/subscription"

    module Webhooks
      autoload :AccountUpdated, "pay/stripe/webhooks/account_updated"
      autoload :ChargeRefunded, "pay/stripe/webhooks/charge_refunded"
      autoload :ChargeSucceeded, "pay/stripe/webhooks/charge_succeeded"
      autoload :CheckoutSessionCompleted, "pay/stripe/webhooks/checkout_session_completed"
      autoload :CheckoutSessionAsyncPaymentSucceeded, "pay/stripe/webhooks/checkout_session_async_payment_succeeded"
      autoload :CustomerDeleted, "pay/stripe/webhooks/customer_deleted"
      autoload :CustomerUpdated, "pay/stripe/webhooks/customer_updated"
      autoload :PaymentActionRequired, "pay/stripe/webhooks/payment_action_required"
      autoload :PaymentIntentSucceeded, "pay/stripe/webhooks/payment_intent_succeeded"
      autoload :PaymentMethodAttached, "pay/stripe/webhooks/payment_method_attached"
      autoload :PaymentMethodDetached, "pay/stripe/webhooks/payment_method_detached"
      autoload :PaymentMethodUpdated, "pay/stripe/webhooks/payment_method_updated"
      autoload :SubscriptionCreated, "pay/stripe/webhooks/subscription_created"
      autoload :SubscriptionDeleted, "pay/stripe/webhooks/subscription_deleted"
      autoload :SubscriptionRenewing, "pay/stripe/webhooks/subscription_renewing"
      autoload :SubscriptionUpdated, "pay/stripe/webhooks/subscription_updated"
      autoload :SubscriptionTrialWillEnd, "pay/stripe/webhooks/subscription_trial_will_end"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:stripe) && defined?(::Stripe)

      Pay::Engine.version_matches?(required: "~> 8", current: ::Stripe::VERSION) || (raise "[Pay] stripe gem must be version ~> 8")
    end

    def self.setup
      ::Stripe.api_key = private_key
      ::Stripe.api_version = "2022-11-15"

      # Used by Stripe to identify Pay for support
      ::Stripe.set_app_info("PayRails", partner_id: "pp_partner_IqhY0UExnJYLxg", version: Pay::VERSION, url: "https://github.com/pay-rails/pay")

      # Automatically retry requests that fail
      # This automatically includes idempotency keys in the request to guarantee that retires are safe
      # https://github.com/stripe/stripe-ruby#configuring-automatic-retries
      ::Stripe.max_network_retries = 2
    end

    def self.public_key
      find_value_by_name(:stripe, :public_key)
    end

    def self.private_key
      find_value_by_name(:stripe, :private_key)
    end

    def self.signing_secret
      find_value_by_name(:stripe, :signing_secret)
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        # Listen to the charge event to make sure we get non-subscription
        # purchases as well. Invoice is only for subscriptions and manual creation
        # so it does not include individual charges.
        events.subscribe "stripe.charge.succeeded", Pay::Stripe::Webhooks::ChargeSucceeded.new
        events.subscribe "stripe.charge.refunded", Pay::Stripe::Webhooks::ChargeRefunded.new

        events.subscribe "stripe.payment_intent.succeeded", Pay::Stripe::Webhooks::PaymentIntentSucceeded.new

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

        # When a customers subscription trial period is 3 days from ending or ended immediately this event is fired
        events.subscribe "stripe.customer.subscription.trial_will_end", Pay::Stripe::Webhooks::SubscriptionTrialWillEnd.new

        # Monitor changes for customer's default card changing
        events.subscribe "stripe.customer.updated", Pay::Stripe::Webhooks::CustomerUpdated.new

        # If a customer was deleted in Stripe, their subscriptions should be cancelled
        events.subscribe "stripe.customer.deleted", Pay::Stripe::Webhooks::CustomerDeleted.new

        # If a customer's payment source was deleted in Stripe, we should update as well
        events.subscribe "stripe.payment_method.attached", Pay::Stripe::Webhooks::PaymentMethodAttached.new
        events.subscribe "stripe.payment_method.updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        events.subscribe "stripe.payment_method.card_automatically_updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        events.subscribe "stripe.payment_method.detached", Pay::Stripe::Webhooks::PaymentMethodDetached.new

        # If an account is updated in stripe, we should update it as well
        events.subscribe "stripe.account.updated", Pay::Stripe::Webhooks::AccountUpdated.new

        # Handle subscriptions in Stripe Checkout Sessions
        events.subscribe "stripe.checkout.session.completed", Pay::Stripe::Webhooks::CheckoutSessionCompleted.new
        events.subscribe "stripe.checkout.session.async_payment_succeeded", Pay::Stripe::Webhooks::CheckoutSessionAsyncPaymentSucceeded.new
      end
    end
  end
end
