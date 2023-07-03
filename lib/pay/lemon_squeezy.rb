module Pay
  module LemonSqueezy
    autoload :Billable, "pay/lemon_squeezy/billable"
    autoload :Charge, "pay/lemon_squeezy/charge"
    autoload :Error, "pay/lemon_squeezy/error"
    autoload :PaymentMethod, "pay/lemon_squeezy/payment_method"
    autoload :Subscription, "pay/lemon_squeezy/subscription"

    module Webhooks
      autoload :SignatureVerifier, "pay/lemon_squeezy/webhooks/signature_verifier"
      autoload :SubscriptionCreated, "pay/lemon_squeezy/webhooks/subscription_created"
      autoload :SubscriptionCancelled, "pay/lemon_squeezy/webhooks/subscription_cancelled"
      autoload :SubscriptionPaymentRefunded, "pay/lemon_squeezy/webhooks/subscription_payment_refunded"
      autoload :SubscriptionPaymentSucceeded, "pay/lemon_squeezy/webhooks/subscription_payment_succeeded"
      autoload :SubscriptionUpdated, "pay/lemon_squeezy/webhooks/subscription_updated"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:lemon_squeezy) && defined?(::LemonSqueezy)

      Pay::Engine.version_matches?(required: "~> 0.2", current: ::LemonSqueezy::VERSION) || (raise "[Pay] lemonsqueezy gem must be version ~> 0.2")
    end

    def self.client
      ::LemonSqueezy::Client.new access_token: access_token
    end

    def self.access_token
      find_value_by_name(:lemon_squeezy, :access_token)
    end

    def self.passthrough(owner:, **options)
      options.merge(owner_sgid: owner.to_sgid.to_s).to_json
    end

    def self.parse_passthrough(passthrough)
      JSON.parse(passthrough)
    end

    def self.owner_from_passthrough(passthrough)
      GlobalID::Locator.locate_signed parse_passthrough(passthrough)["owner_sgid"]
    rescue JSON::ParserError
      nil
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "lemon_squeezy.subscription_created", Pay::LemonSqueezy::Webhooks::SubscriptionCreated.new
        events.subscribe "lemon_squeezy.subscription_updated", Pay::LemonSqueezy::Webhooks::SubscriptionUpdated.new
        events.subscribe "lemon_squeezy.subscription_cancelled", Pay::LemonSqueezy::Webhooks::SubscriptionCancelled.new
        events.subscribe "lemon_squeezy.subscription_payment_succeeded", Pay::LemonSqueezy::Webhooks::SubscriptionPaymentSucceeded.new
        events.subscribe "lemon_squeezy.subscription_payment_refunded", Pay::LemonSqueezy::Webhooks::SubscriptionPaymentRefunded.new
      end
    end
  end
end
