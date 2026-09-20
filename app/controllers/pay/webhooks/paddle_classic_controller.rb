module Pay
  module Webhooks
    class PaddleClassicController < BaseController
      private

      def verified_event
        event = verified_params
        return event if Pay::PaddleClassic::Webhooks::SignatureVerifier.new(event).verify
        raise Pay::PaddleClassic::Error, "Unable to verify Paddle webhook event"
      end

      def event_type(event)
        event["alert_name"]
      end
    end
  end
end
