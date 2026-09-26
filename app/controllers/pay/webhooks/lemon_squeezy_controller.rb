module Pay
  module Webhooks
    class LemonSqueezyController < BaseController
      private

      def verified_event
        raise Pay::LemonSqueezy::Error, "Unable to verify Lemon Squeezy webhook signature" unless valid_signature?(request.headers["X-Signature"])
        verified_params
      end

      def event_type(event)
        event.dig("meta", "event_name")
      end

      def valid_signature?(signature)
        secret = Pay::LemonSqueezy.signing_secret
        raise Pay::LemonSqueezy::Error, "Cannot verify signature without a Lemon Squeezy signing secret" if secret.blank?
        return false if signature.blank?

        hmac = OpenSSL::HMAC.hexdigest("sha256", secret, request.raw_post)
        ActiveSupport::SecurityUtils.secure_compare(hmac, signature)
      end
    end
  end
end
