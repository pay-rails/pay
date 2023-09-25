module Pay
  module Webhooks
    class LagoController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        return head :bad_request unless (event = verified_event)
        queue_event(event)
        head :ok
      end

      private

      def queue_event(event)
        return unless Pay::Webhooks.delegator.listening?("lago.#{event["webhook_type"]}")

        record = Pay::Webhook.create!(processor: :lago, event_type: event["webhook_type"], event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      def verified_event
        payload_json = JSON.parse(request.raw_post)
        return false unless valid_signature?(request.headers["HTTP_X_LAGO_SIGNATURE"], payload_json)
        payload_json
      rescue JSON::ParserError
        false
      end

      def valid_signature?(signature, payload)
        public_key = Pay::Lago.webhook_public_key
        Pay::Lago.client.webhooks.valid_signature?(signature, payload, public_key)
      end

      def verified_webhook?(signature, payload)
        Pay::Lago.client.webhooks.valid_signature?(signature, payload_json, public_key)
      end
    end
  end
end
