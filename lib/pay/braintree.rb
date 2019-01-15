require 'pay/braintree/api'
require 'pay/braintree/billable'
require 'pay/braintree/charge'
require 'pay/braintree/subscription'

module Pay
  module Braintree
    def self.setup
      Pay::Braintree::Api.set_api_keys

      Pay.charge_model.include Pay::Braintree::Charge
      Pay.subscription_model.include Pay::Braintree::Subscription
      Pay.user_model.include Pay::Braintree::Billable
    end
  end
end
