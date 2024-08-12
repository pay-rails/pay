module Pay
  module LemonSqueezy
    class Error < Pay::Error
      delegate :message, to: :cause
    end

    module Webhooks
      autoload :Subscription, "pay/lemon_squeezy/webhooks/subscription"
      autoload :Payment, "pay/lemon_squeezy/webhooks/payment"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:lemon_squeezy) && defined?(::LemonSqueezy)

      Pay::Engine.version_matches?(required: "~> 1.0", current: ::LemonSqueezy::VERSION) || (raise "[Pay] lemonsqueezy gem must be version ~> 1.0")
    end

    def self.setup
      ::LemonSqueezy.config.api_key = api_key
    end

    def self.api_key
      find_value_by_name(:lemon_squeezy, :api_key)
    end

    def self.store_id
      find_value_by_name(:lemon_squeezy, :store_id)
    end

    def self.signing_secret
      find_value_by_name(:lemon_squeezy, :signing_secret)
    end

    def self.passthrough(owner:, **options)
      owner.to_sgid.to_s
    end

    def self.owner_from_passthrough(passthrough)
      GlobalID::Locator.locate_signed passthrough
    rescue JSON::ParserError
      nil
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "lemon_squeezy.subscription_payment_success", Pay::LemonSqueezy::Webhooks::Payment.new
        events.subscribe "lemon_squeezy.subscription_created", Pay::LemonSqueezy::Webhooks::Subscription.new
        events.subscribe "lemon_squeezy.subscription_updated", Pay::LemonSqueezy::Webhooks::Subscription.new
      end
    end
  end
end
