# frozen_string_literal: true

module Pay
  module PaddleClassic
    class Error < Pay::Error
      # Wrapped processor errors report the original message; errors raised with a string keep theirs
      def message
        cause&.message || super
      end
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

    credential :vendor_id, :vendor_auth_code, :environment, :public_key, :public_key_file, :public_key_base64

    REQUIRED_VERSION = "~> 3"

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:paddle_classic) && defined?(::Paddle)

      Pay::Engine.version_matches?(required: REQUIRED_VERSION,
        current: ::Paddle::VERSION) || (raise "[Pay] paddle gem must be version #{REQUIRED_VERSION}")
    end

    # The client memoizes a Faraday connection, which can't be shared, so each non-main Ractor builds its own
    def self.client
      if ::Ractor.current == ::Ractor.main
        @client ||= new_client
      else
        ::Ractor.current[:pay_paddle_classic_client] ||= new_client
      end
    end

    def self.new_client
      Paddle::Classic::Client.new(
        vendor_id: vendor_id,
        vendor_auth_code: vendor_auth_code,
        sandbox: environment != "production"
      )
    end

    def self.environment
      super || "production"
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
