module Pay
  module Webhooks
    class PaddleController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create

        # puts "*****"
        # puts request.headers["Paddle-Signature"]
        # puts "*****"


        queue_event(verify_params.as_json)
        head :ok
      rescue Pay::Paddle::Error
        head :bad_request
      end

      private

      def queue_event(event)
        return unless Pay::Webhooks.delegator.listening?("paddle.#{params[:event_type]}")

        record = Pay::Webhook.create!(processor: :paddle, event_type: params[:event_type], event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      # def verified_event
      #   event = verify_params.as_json
      #   verifier = Pay::Paddle::Webhooks::SignatureVerifier.new(event)
      #   return event if verifier.verify
      #   raise Pay::Paddle::Error, "Unable to verify Paddle webhook event"
      # end

      def verify_params
        params.except(:action, :controller).permit!
      end
    end
  end
end
