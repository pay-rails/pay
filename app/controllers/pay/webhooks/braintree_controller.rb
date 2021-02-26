module Pay
  module Webhooks
    class BraintreeController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        delegate_event(verified_event)
        head :ok
      rescue ::Braintree::InvalidSignature
        head :bad_request
      end

      private

      def delegate_event(event)
        Pay::Webhooks.instrument type: "braintree.#{event.kind}", event: event
      end

      def verified_event
        Pay.braintree_gateway.webhook_notification.parse(params[:bt_signature], params[:bt_payload])
      end
    end
  end
end
