module Pay
  module Webhooks
    class PaddleController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        verifier = Pay::Paddle::Webhooks::SignatureVerifier.new(check_params.as_json)
        if verifier.verify
          case params["alert_name"]
          when "subscription_created"
            Pay::Paddle::Webhooks::SubscriptionCreated.new(check_params.as_json)
          when "subscription_updated"
            Pay::Paddle::Webhooks::SubscriptionUpdated.new(check_params.as_json)
          when "subscription_cancelled"
            Pay::Paddle::Webhooks::SubscriptionCancelled.new(check_params.as_json)
          when "subscription_payment_succeeded"
            Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new(check_params.as_json)
          when "subscription_payment_refunded"
            Pay::Paddle::Webhooks::SubscriptionPaymentRefunded.new(check_params.as_json)
          end
          render json: {success: true}, status: :ok
        else
          head :ok
        end
      end

      private

      def check_params
        params.except(:action, :controller).permit!
      end
    end
  end
end