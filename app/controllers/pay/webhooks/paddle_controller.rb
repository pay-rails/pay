module Pay
  module Webhooks
    class PaddleController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        delegate_event(verified_event)
        head :ok
      rescue Pay::Paddle::Error
        head :bad_request
      end

      private

      def delegate_event(event)
        Pay::Webhooks.instrument type: "paddle.#{type}", event: event
      end

      def type
        params[:alert_name]
      end

      def verified_event
        event = check_params.as_json
        verifier = Pay::Paddle::Webhooks::SignatureVerifier.new(event)
        return event if verifier.verify
        raise Pay::Paddle::Error, "Unable to verify Paddle webhook event"
      end

      def check_params
        params.except(:action, :controller).permit!
      end
    end
  end
end
