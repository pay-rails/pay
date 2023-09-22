module Pay
  module Webhooks
    class LagoController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        return head :bad_request unless verified_webhook?(request.headers["HTTP_X_LAGO_SIGNATURE"], request.raw_post)
        queue_event(params)
        head :ok
      end

      private

      def queue_event(event)
        return unless Pay::Webhooks.delegator.listening?("lago.#{event["webhook_type"]}")

        record = Pay::Webhook.create!(processor: :lago, event_type: event["webhook_type"], event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      def verified_webhook?(signature, payload)
        public_key = Pay::Lago.webhook_public_key
        payload_json = JSON.parse(payload)
        Pay::Lago.client.webhooks.valid_signature?(signature, payload_json, public_key)
      end
    end
  end
end
