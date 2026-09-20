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
        return false if signature.blank?

        hmac = OpenSSL::HMAC.hexdigest("sha256", Pay::LemonSqueezy.signing_secret.to_s, request.raw_post)
        ActiveSupport::SecurityUtils.secure_compare(hmac, signature)
      end
    end
  end
end
