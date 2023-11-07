module Pay
  module Webhooks
    class LemonSqueezyController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        queue_event(verify_params.as_json)
        head :ok
        # rescue Pay::LemonSqueezy::Error
        #   head :bad_request
      end

      private

      def queue_event(event)
        event_name = request.headers["X-Event-Name"]
        return unless Pay::Webhooks.delegator.listening?("lemon_squeezy.#{event_name}")

        evnt = event

        evnt["id"] = params["data"]["id"]

        if params["meta"]["custom_data"]
          passthrough = params["meta"]["custom_data"]["passthrough"]
          evnt["passthrough"] = passthrough
        end

        record = Pay::Webhook.create!(
          processor: :lemon_squeezy,
          event_type: event_name,
          event: evnt
        )

        record.process!

        # Pay::Webhooks::ProcessJob.perform_later(record)
      end

      # def queue_event(event)
      #   event_type = params[:meta][:event_name]
      #   return unless Pay::Webhooks.delegator.listening?("lemon_squeezy.#{event_type}")

      #   record = Pay::Webhook.create!(processor: :lemon_squeezy, event_type: event_type, event: event)
      #   record.process!
      #   # Pay::Webhooks::ProcessJob.perform_later(record)
      # end

      # def verified_event
      #   event = verify_params.as_json
      #   verifier = Pay::Paddle::Webhooks::SignatureVerifier.new(event)
      #   return event if verifier.verify
      #   raise Pay::Paddle::Error, "Unable to verify Paddle webhook event"
      # end

      def verify_params
        # params.except(:action, :controller).permit!
        params["data"]["attributes"].permit!
      end
    end
  end
end
