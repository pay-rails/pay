module Pay
  module Webhooks
    class PaddleClassicController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        queue_event(verified_event)
        head :ok
      rescue Pay::PaddleClassic::Error
        head :bad_request
      end

      private

      def queue_event(event)
        return unless Pay::Webhooks.delegator.listening?("paddle.#{params[:alert_name]}")

        record = Pay::Webhook.create!(processor: :paddle_classic, event_type: params[:alert_name], event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      def verified_event
        event = verify_params.as_json
        verifier = Pay::PaddleClassic::Webhooks::SignatureVerifier.new(event)
        return event if verifier.verify
        raise Pay::PaddleClassic::Error, "Unable to verify Paddle webhook event"
      end

      def verify_params
        params.except(:action, :controller).permit!
      end
    end
  end
end
