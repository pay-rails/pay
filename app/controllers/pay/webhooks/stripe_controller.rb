module Pay
  module Webhooks
    class StripeController < BaseController
      private

      def verified_event
        payload = request.body.read
        signature = request.headers["Stripe-Signature"]
        secrets = Array.wrap(Pay::Stripe.signing_secret)
        raise Pay::Stripe::Error, "Cannot verify signature without a Stripe signing secret" if secrets.empty?

        # Several secrets can be configured while rotating; accept the first that verifies
        secrets.each_with_index do |secret, i|
          return ::Stripe::Webhook.construct_event(payload, signature, secret.to_s)
        rescue ::Stripe::SignatureVerificationError => e
          next unless i == secrets.length - 1
          logger.error e.message
          raise Pay::Stripe::Error, e
        end
      end

      def event_type(event)
        event.type
      end

      def queue?(event)
        event.livemode || Pay::Stripe.webhook_receive_test_events
      end
    end
  end
end
