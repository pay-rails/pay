module Pay
  module Webhooks
    # Verifies a processor's webhook request and queues the event for Pay::Webhooks::ProcessJob.
    #
    # Subclasses implement verified_event, which raises a Pay::Error when the signature doesn't
    # check out, and event_type. Processors whose parsed event can't be serialized override
    # event_payload; Stripe overrides queue? to skip test-mode events.
    class BaseController < ActionController::API
      rescue_from Pay::Error, with: :invalid_signature

      def create
        event = verified_event
        queue_event(event) if queue?(event)
        head :ok
      end

      private

      def queue?(event)
        true
      end

      def event_payload(event)
        event
      end

      def queue_event(event)
        type = event_type(event)
        return unless Pay::Webhooks.delegator.listening?("#{processor}.#{type}")

        record = Pay::Webhook.create!(processor: processor, event_type: type, event: event_payload(event))
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      # "stripe", "paddle_billing", and so on, from the controller name
      def processor
        controller_name
      end

      # The request body as a plain hash, for processors that sign the request rather than hand us an event object
      def verified_params
        params.except(:action, :controller).permit!.as_json
      end

      def invalid_signature
        head :bad_request
      end
    end
  end
end
