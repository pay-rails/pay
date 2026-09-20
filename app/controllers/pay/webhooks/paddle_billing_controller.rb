module Pay
  module Webhooks
    class PaddleBillingController < BaseController
      private

      def verified_event
        raise Pay::PaddleBilling::Error, "Unable to verify Paddle webhook signature" unless valid_signature?(request.headers["Paddle-Signature"])
        verified_params
      end

      def event_type(event)
        event["event_type"]
      end

      # The header looks like "ts=1671552777;h1=eb4d0dc8..."
      def valid_signature?(signature)
        parts = signature.to_s.split(";").filter_map { |part| part.split("=", 2) if part.include?("=") }.to_h
        ts, h1 = parts.values_at("ts", "h1")
        return false if ts.blank? || h1.blank?

        hmac = OpenSSL::HMAC.hexdigest("sha256", Pay::PaddleBilling.signing_secret.to_s, "#{ts}:#{request.raw_post}")
        ActiveSupport::SecurityUtils.secure_compare(hmac, h1)
      end
    end
  end
end
