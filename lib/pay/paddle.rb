require "pay/env"
require "pay/paddle/billable"
require "pay/paddle/charge"
require "pay/paddle/subscription"
require "pay/paddle/webhooks"

module Pay
  module Paddle
    include Env

    extend self

    def setup
      ::PaddlePay.config.vendor_id = vendor_id
      ::PaddlePay.config.vendor_auth_code = vendor_auth_code

      Pay.charge_model.include Pay::Paddle::Charge
      Pay.subscription_model.include Pay::Paddle::Subscription
      Pay.billable_models.each { |model| model.include Pay::Paddle::Billable }
    end

    def vendor_id
      find_value_by_name(:paddle, :vendor_id)
    end

    def vendor_auth_code
      find_value_by_name(:paddle, :vendor_auth_code)
    end

    def public_key_base64
      find_value_by_name(:paddle, :public_key_base64)
    end
  end
end
