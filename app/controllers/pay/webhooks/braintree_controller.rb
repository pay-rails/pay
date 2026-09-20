module Pay
  module Webhooks
    class BraintreeController < BaseController
      private

      def verified_event
        Pay.braintree_gateway.webhook_notification.parse(params[:bt_signature], params[:bt_payload])
      rescue ::Braintree::InvalidSignature => e
        raise Pay::Braintree::Error, e
      end

      def event_type(event)
        event.kind
      end

      # The parsed notification can't be serialized, so store the signed payload and parse it again in the job
      def event_payload(event)
        {bt_signature: params[:bt_signature], bt_payload: params[:bt_payload]}
      end
    end
  end
end
