module Pay
  module Paddle
    autoload :Billable, "pay/paddle/billable"
    autoload :Charge, "pay/paddle/charge"
    autoload :Error, "pay/paddle/error"
    autoload :PaymentMethod, "pay/paddle/payment_method"
    autoload :Subscription, "pay/paddle/subscription"

    module Webhooks
      autoload :SignatureVerifier, "pay/paddle/webhooks/signature_verifier"
      autoload :SubscriptionCreated, "pay/paddle/webhooks/subscription_created"
      autoload :SubscriptionCancelled, "pay/paddle/webhooks/subscription_cancelled"
      autoload :SubscriptionPaymentRefunded, "pay/paddle/webhooks/subscription_payment_refunded"
      autoload :SubscriptionPaymentSucceeded, "pay/paddle/webhooks/subscription_payment_succeeded"
      autoload :SubscriptionUpdated, "pay/paddle/webhooks/subscription_updated"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:paddle) && defined?(::Paddle)

      Pay::Engine.version_matches?(required: "~> 1.1", current: ::Paddle::VERSION) || (raise "[Pay] paddle gem must be version ~> 1.1")
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
        # events.subscribe "paddle.subscription_updated", Pay::Paddle::Webhooks::SubscriptionUpdated.new
        # events.subscribe "paddle.subscription_cancelled", Pay::Paddle::Webhooks::SubscriptionCancelled.new
        # events.subscribe "paddle.subscription_payment_succeeded", Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new
        # events.subscribe "paddle.subscription_payment_refunded", Pay::Paddle::Webhooks::SubscriptionPaymentRefunded.new
      end
    end
  end
end
