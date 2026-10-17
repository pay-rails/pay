# frozen_string_literal: true

module Pay
  module PaddleBilling
    class Error < Pay::Error
      # Wrapped processor errors report the original message; errors raised with a string keep theirs
      def message
        cause&.message || super
      end
    end

    module Webhooks
      autoload :Subscription, "pay/paddle_billing/webhooks/subscription"
      autoload :TransactionCompleted, "pay/paddle_billing/webhooks/transaction_completed"
    end

    extend Env

    credential :environment, :client_token, :api_key, :signing_secret

    REQUIRED_VERSION = "~> 3"

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:paddle_billing) && defined?(::Paddle)

      Pay::Engine.version_matches?(required: REQUIRED_VERSION,
        current: ::Paddle::VERSION) || (raise "[Pay] paddle gem must be version #{REQUIRED_VERSION}")
    end

    def self.setup
      ::Paddle.config.environment = environment
      ::Paddle.config.api_key = api_key
    end

    def self.environment
      super || "production"
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "paddle_billing.subscription.activated", Pay::PaddleBilling::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.canceled", Pay::PaddleBilling::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.created", Pay::PaddleBilling::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.imported", Pay::PaddleBilling::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.past_due", Pay::PaddleBilling::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.paused", Pay::PaddleBilling::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.resumed", Pay::PaddleBilling::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.trialing", Pay::PaddleBilling::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.updated", Pay::PaddleBilling::Webhooks::Subscription.new
        events.subscribe "paddle_billing.transaction.completed", Pay::PaddleBilling::Webhooks::TransactionCompleted.new
      end
    end

    def self.sync_transaction(transaction_id)
      transaction = ::Paddle::Transaction.retrieve(id: transaction_id)

      if transaction.subscription_id.present?
        Pay::PaddleBilling::Subscription.sync(transaction.subscription_id)
      else
        Pay::PaddleBilling::Charge.sync(transaction_id, object: transaction)
      end
    end
  end
end
