module Pay
  module Braintree
    class Error < Pay::Error
      # For any manually raised Braintree error results (for failure responses)
      # we can raise this exception manually but treat it as if we wrapped an exception

      attr_reader :result

      def initialize(result)
        if result.is_a?(::Braintree::ErrorResult)
          super(result.message)
          @result = result
        else
          super
        end
      end

      def cause
        super || result
      end
    end

    class AuthorizationError < Error
      def message
        I18n.t("pay.errors.braintree.authorization")
      end
    end

    module Webhooks
      autoload :SubscriptionCanceled, "pay/braintree/webhooks/subscription_canceled"
      autoload :SubscriptionChargedSuccessfully, "pay/braintree/webhooks/subscription_charged_successfully"
      autoload :SubscriptionChargedUnsuccessfully, "pay/braintree/webhooks/subscription_charged_unsuccessfully"
      autoload :SubscriptionExpired, "pay/braintree/webhooks/subscription_expired"
      autoload :SubscriptionTrialEnded, "pay/braintree/webhooks/subscription_trial_ended"
      autoload :SubscriptionWentActive, "pay/braintree/webhooks/subscription_went_active"
      autoload :SubscriptionWentPastDue, "pay/braintree/webhooks/subscription_went_past_due"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:braintree) && defined?(::Braintree)

      Pay::Engine.version_matches?(required: "~> 4", current: ::Braintree::Version::String) || (raise "[Pay] braintree gem must be version ~> 4")
    end

    def self.setup
      Pay.braintree_gateway = ::Braintree::Gateway.new(
        environment: environment.to_sym,
        merchant_id: merchant_id,
        public_key: public_key,
        private_key: private_key
      )
    end

    def self.public_key
      find_value_by_name(:braintree, :public_key)
    end

    def self.private_key
      find_value_by_name(:braintree, :private_key)
    end

    def self.merchant_id
      find_value_by_name(:braintree, :merchant_id)
    end

    def self.environment
      find_value_by_name(:braintree, :environment) || "sandbox"
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "braintree.subscription_canceled", Pay::Braintree::Webhooks::SubscriptionCanceled.new
        events.subscribe "braintree.subscription_charged_successfully", Pay::Braintree::Webhooks::SubscriptionChargedSuccessfully.new
        events.subscribe "braintree.subscription_charged_unsuccessfully", Pay::Braintree::Webhooks::SubscriptionChargedUnsuccessfully.new
        events.subscribe "braintree.subscription_expired", Pay::Braintree::Webhooks::SubscriptionExpired.new
        events.subscribe "braintree.subscription_trial_ended", Pay::Braintree::Webhooks::SubscriptionTrialEnded.new
        events.subscribe "braintree.subscription_went_active", Pay::Braintree::Webhooks::SubscriptionWentActive.new
        events.subscribe "braintree.subscription_went_past_due", Pay::Braintree::Webhooks::SubscriptionWentPastDue.new
      end
    end
  end
end
