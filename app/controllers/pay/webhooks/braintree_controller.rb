module Pay
  module Webhooks
    class BraintreeController < Pay::ApplicationController
      skip_forgery_protection if Rails.application.config.action_controller.default_protect_from_forgery

      def create
        queue_event(verified_event)
        head :ok
      rescue ::Braintree::InvalidSignature
        head :bad_request
      end

      private

      def queue_event(event)
        return unless Pay::Webhooks.delegator.listening?("braintree.#{event.kind}")

        record = Pay::Webhook.create!(
          processor: :braintree,
          event_type: event.kind,
          event: { bt_signature: params[:bt_signature], bt_payload: params[:bt_payload] }
        )
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      def verified_event
        Pay.braintree_gateway.webhook_notification.parse(params[:bt_signature], params[:bt_payload])
      end
    end
  end
end
