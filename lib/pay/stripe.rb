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
      autoload :PaymentFailed, "pay/stripe/webhooks/payment_failed"
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

    REQUIRED_VERSION = "~> 12"

    # A list of database model names that include Pay
    # Used for safely looking up models with client_reference_id
    mattr_accessor :model_names, default: Set.new

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:stripe) && defined?(::Stripe)

      Pay::Engine.version_matches?(required: REQUIRED_VERSION, current: ::Stripe::VERSION) || (raise "[Pay] stripe gem must be version #{REQUIRED_VERSION}")
    end

    def self.setup
      ::Stripe.api_key = private_key

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

    def self.webhook_receive_test_events
      value = find_value_by_name(:stripe, :webhook_receive_test_events)
      value.blank? ? true : ActiveModel::Type::Boolean.new.cast(value)
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

        # If an invoice payment fails, we want to notify the user via email to update their payment details
        events.subscribe "stripe.invoice.payment_failed", Pay::Stripe::Webhooks::PaymentFailed.new

        # If a subscription is manually created on Stripe, we want to sync
        events.subscribe "stripe.customer.subscription.created", Pay::Stripe::Webhooks::SubscriptionCreated.new

        # If the plan, quantity, or trial ending date is updated on Stripe, we want to sync
        events.subscribe "stripe.customer.subscription.updated", Pay::Stripe::Webhooks::SubscriptionUpdated.new

        # When a customers subscription is canceled, we want to update our records
        events.subscribe "stripe.customer.subscription.deleted", Pay::Stripe::Webhooks::SubscriptionDeleted.new

        # When a customers subscription trial period is 3 days from ending or ended immediately this event is fired
        events.subscribe "stripe.customer.subscription.trial_will_end", Pay::Stripe::Webhooks::SubscriptionTrialWillEnd.new

        # Monitor changes for customer's default card changing and invoice credit updates
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

    def self.to_client_reference_id(record)
      raise ArgumentError, "#{record.class.name} does not include Pay. Allowed models: #{model_names.to_a.join(", ")}" unless model_names.include?(record.class.name)
      [record.class.name, record.id].join("_")
    end

    def self.find_by_client_reference_id(client_reference_id)
      # If there is a client reference ID, make sure we have a Pay::Customer record
      # client_reference_id should be in the format of "User/1"
      model_name, id = client_reference_id.split("_", 2)

      # Only allow model names that use Pay
      return unless model_names.include?(model_name)

      model_name.constantize.find(id)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "[Pay] Unable to locate record with: #{client_reference_id}"
      nil
    end

    def sync_checkout_session(session_id, stripe_account: nil)
      checkout_session = ::Stripe::Checkout::Session.retrieve({id: session_id, expand: %(payment_intent.latest_charge)}, {stripe_account: stripe_account}.compact)
      case checkout_session.mode
      when "payment"
        Pay::Stripe::Charge.sync(checkout_session.payment_intent.latest_charge.id, stripe_account: stripe_account)
      when "subscription"
        Pay::Stripe::Subscription.sync(checkout_session.subscription, stripe_account: stripe_account)
      end
    end
  end
end
