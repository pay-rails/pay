module Pay
  module Webhooks
    class StripeController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        event = verified_event
        queue_event(event) if event.livemode || Pay::Stripe.webhook_receive_test_events
        head :ok
      rescue ::Stripe::SignatureVerificationError => e
        log_error(e)
        head :bad_request
      end

      private

      def queue_event(event)
        return unless Pay::Webhooks.delegator.listening?("stripe.#{event.type}")

        record = Pay::Webhook.create!(processor: :stripe, event_type: event.type, event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      def verified_event
        payload = request.body.read
        signature = request.headers["Stripe-Signature"]
        possible_secrets = secrets(payload, signature)

        possible_secrets.each_with_index do |secret, i|
          return ::Stripe::Webhook.construct_event(payload, signature, secret.to_s)
        rescue ::Stripe::SignatureVerificationError
          raise if i == possible_secrets.length - 1
          next
        end
      end

      def secrets(payload, signature)
        secret = Pay::Stripe.signing_secret
        return Array.wrap(secret) if secret
        raise ::Stripe::SignatureVerificationError.new("Cannot verify signature without a Stripe signing secret", signature, http_body: payload)
      end

      def log_error(e)
        logger.error e.message
        e.backtrace.each { |line| logger.error "  #{line}" }
      end
    end
  end
end
