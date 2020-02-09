require "pay/env"
require "pay/braintree/billable"
require "pay/braintree/charge"
require "pay/braintree/subscription"

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
      Pay.user_model.include Pay::Braintree::Billable
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
  end
end
