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
      return false unless Pay.enabled_processors.include?(:paddle) && defined?(::PaddlePay)

      Pay::Engine.version_matches?(required: "~> 0.2", current: ::PaddlePay::VERSION) || (raise "[Pay] paddle gem must be version ~> 0.2")
    end

    def self.setup
      ::PaddlePay.config.vendor_id = vendor_id
      ::PaddlePay.config.vendor_auth_code = vendor_auth_code
      ::PaddlePay.config.environment = environment
    end

    def self.vendor_id
      find_value_by_name(:paddle, :vendor_id)
    end

    def self.vendor_auth_code
      find_value_by_name(:paddle, :vendor_auth_code)
    end

    def self.environment
      find_value_by_name(:paddle, :environment) || "production"
    end

    def self.public_key
      find_value_by_name(:paddle, :public_key)
    end

    def self.public_key_file
      find_value_by_name(:paddle, :public_key_file)
    end

    def self.public_key_base64
      find_value_by_name(:paddle, :public_key_base64)
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
        events.subscribe "paddle.subscription_created", Pay::Paddle::Webhooks::SubscriptionCreated.new
        events.subscribe "paddle.subscription_updated", Pay::Paddle::Webhooks::SubscriptionUpdated.new
        events.subscribe "paddle.subscription_cancelled", Pay::Paddle::Webhooks::SubscriptionCancelled.new
        events.subscribe "paddle.subscription_payment_succeeded", Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new
        events.subscribe "paddle.subscription_payment_refunded", Pay::Paddle::Webhooks::SubscriptionPaymentRefunded.new
      end
    end
  end
end
