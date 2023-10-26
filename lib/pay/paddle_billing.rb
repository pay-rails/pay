module Pay
  module PaddleBilling
    autoload :Billable, "pay/paddle_billing/billable"
    autoload :Charge, "pay/paddle_billing/charge"
    autoload :Error, "pay/paddle_billing/error"
    autoload :PaymentMethod, "pay/paddle_billing/payment_method"
    autoload :Subscription, "pay/paddle_billing/subscription"

    module Webhooks
      autoload :Subscription, "pay/paddle_billing/webhooks/subscription"
      autoload :TransactionCompleted, "pay/paddle_billing/webhooks/transaction_completed"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:paddle_billing) && defined?(::Paddle)

      Pay::Engine.version_matches?(required: "~> 2.1", current: ::Paddle::VERSION) || (raise "[Pay] paddle gem must be version ~> 2.1")
    end

    def self.setup
      ::Paddle.config.environment = environment
      ::Paddle.config.api_key = api_key
    end

    def self.environment
      find_value_by_name(:paddle_billing, :environment) || "production"
    end

    def self.seller_id
      find_value_by_name(:paddle_billing, :seller_id)
    end

    def self.api_key
      find_value_by_name(:paddle_billing, :api_key)
    end

    def self.signing_secret
      find_value_by_name(:paddle_billing, :signing_secret)
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "paddle_billing.subscription.activated", Pay::Paddle::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.canceled", Pay::Paddle::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.created", Pay::Paddle::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.imported", Pay::Paddle::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.past_due", Pay::Paddle::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.paused", Pay::Paddle::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.resumed", Pay::Paddle::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.trialing", Pay::Paddle::Webhooks::Subscription.new
        events.subscribe "paddle_billing.subscription.updated", Pay::Paddle::Webhooks::Subscription.new

        events.subscribe "paddle_billing.transaction.completed", Pay::Paddle::Webhooks::TransactionCompleted.new
      end
    end
  end
end
