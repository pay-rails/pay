module Pay
  module Braintree
    include Env

    extend self

    def setup
      Pay.braintree_gateway = ::Braintree::Gateway.new(
        environment: environment.to_sym,
        merchant_id: merchant_id,
        public_key: public_key,
        private_key: private_key
      )

      Pay.charge_model.include Pay::Braintree::Charge
      Pay.subscription_model.include Pay::Braintree::Subscription
      Pay.billable_models.each { |model| model.include Pay::Braintree::Billable }

      configure_webhooks
    end

    def public_key
      find_value_by_name(:braintree, :public_key)
    end

    def private_key
      find_value_by_name(:braintree, :private_key)
    end

    def merchant_id
      find_value_by_name(:braintree, :merchant_id)
    end

    def environment
      find_value_by_name(:braintree, :environment) || "sandbox"
    end

    def configure_webhooks
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
