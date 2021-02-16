module Pay
  module Paddle
    include Env

    extend self

    def setup
      ::PaddlePay.config.vendor_id = vendor_id
      ::PaddlePay.config.vendor_auth_code = vendor_auth_code

      configure_webhooks
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

    def passthrough(owner:, **options)
      options.merge(owner_sgid: owner.to_sgid.to_s).to_json
    end

    def configure_webhooks
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
