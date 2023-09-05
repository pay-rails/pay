module Pay
  module Paddle
    autoload :Billable, "pay/paddle/billable"
    autoload :Charge, "pay/paddle/charge"
    autoload :Error, "pay/paddle/error"
    autoload :PaymentMethod, "pay/paddle/payment_method"
    autoload :Subscription, "pay/paddle/subscription"

    module Webhooks
      autoload :SubscriptionCreated, "pay/paddle/webhooks/subscription_created"
      autoload :SubscriptionUpdated, "pay/paddle/webhooks/subscription_updated"
      autoload :SubscriptionActivated, "pay/paddle/webhooks/subscription_activated"
      autoload :TransactionCompleted, "pay/paddle/webhooks/transaction_completed"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:paddle) && defined?(::Paddle)

      Pay::Engine.version_matches?(required: "~> 2.1", current: ::Paddle::VERSION) || (raise "[Pay] paddle gem must be version ~> 2.1")
    end

    def self.setup
      ::Paddle.config.environment = environment
      ::Paddle.config.api_key = api_key
    end

    def self.environment
      find_value_by_name(:paddle, :environment) || "production"
    end

    def self.api_key
      find_value_by_name(:paddle, :api_key)
    end

    def self.signing_secret
      find_value_by_name(:paddle, :signing_secret)
    end

    def self.passthrough(owner:)
      {passthrough: owner.to_sgid.to_s}.to_json
    end

    def self.owner_from_passthrough(passthrough)
      GlobalID::Locator.locate_signed(passthrough)
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "paddle.subscription.created", Pay::Paddle::Webhooks::SubscriptionCreated.new
        events.subscribe "paddle.subscription.updated", Pay::Paddle::Webhooks::SubscriptionUpdated.new
        events.subscribe "paddle.subscription.activated", Pay::Paddle::Webhooks::SubscriptionActivated.new

        events.subscribe "paddle.transaction.completed", Pay::Paddle::Webhooks::TransactionCompleted.new
      end
    end
  end
end
