module Pay
  module PaddleClassic
    class Error < Pay::Error
      delegate :message, to: :cause
    end

    module Webhooks
      autoload :SignatureVerifier, "pay/paddle_classic/webhooks/signature_verifier"
      autoload :SubscriptionCreated, "pay/paddle_classic/webhooks/subscription_created"
      autoload :SubscriptionCancelled, "pay/paddle_classic/webhooks/subscription_cancelled"
      autoload :SubscriptionPaymentRefunded, "pay/paddle_classic/webhooks/subscription_payment_refunded"
      autoload :SubscriptionPaymentSucceeded, "pay/paddle_classic/webhooks/subscription_payment_succeeded"
      autoload :SubscriptionUpdated, "pay/paddle_classic/webhooks/subscription_updated"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:paddle_classic) && defined?(::Paddle)

      Pay::Engine.version_matches?(required: "~> 2.5",
        current: ::Paddle::VERSION) || (raise "[Pay] paddle gem must be version ~> 2.5")
    end

    def self.client
      @client ||= Paddle::Classic::Client.new(
        vendor_id: vendor_id,
        vendor_auth_code: vendor_auth_code,
        sandbox: environment != "production"
      )
    end

    def self.vendor_id
      find_value_by_name(:paddle_classic, :vendor_id)
    end

    def self.vendor_auth_code
      find_value_by_name(:paddle_classic, :vendor_auth_code)
    end

    def self.environment
      find_value_by_name(:paddle_classic, :environment) || "production"
    end

    def self.public_key
      find_value_by_name(:paddle_classic, :public_key)
    end

    def self.public_key_file
      find_value_by_name(:paddle_classic, :public_key_file)
    end

    def self.public_key_base64
      find_value_by_name(:paddle_classic, :public_key_base64)
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
        events.subscribe "paddle_classic.subscription_created", Pay::PaddleClassic::Webhooks::SubscriptionCreated.new
        events.subscribe "paddle_classic.subscription_updated", Pay::PaddleClassic::Webhooks::SubscriptionUpdated.new
        events.subscribe "paddle_classic.subscription_cancelled",
          Pay::PaddleClassic::Webhooks::SubscriptionCancelled.new
        events.subscribe "paddle_classic.subscription_payment_succeeded",
          Pay::PaddleClassic::Webhooks::SubscriptionPaymentSucceeded.new
        events.subscribe "paddle_classic.subscription_payment_refunded",
          Pay::PaddleClassic::Webhooks::SubscriptionPaymentRefunded.new
      end
    end
  end
end
