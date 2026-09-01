module Pay
  module Webhooks
    class SquareController < ActionController::API
      def create
        if valid_signature?(request.headers["x-square-hmacsha256-signature"])
          queue_event(verify_params.as_json)
          head :ok
        else
          head :bad_request
        end
      rescue Pay::Square::Error
        head :bad_request
      end

      private

      def queue_event(event)
        return unless Pay::Webhooks.delegator.listening?("square.#{params[:type]}")

        record = Pay::Webhook.create!(processor: :square, event_type: params[:type], event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      # Square signs the HMAC-SHA256 over (notification_url + raw body), base64-encoded.
      # notification_url must match the URL registered with Square; behind a proxy
      # request.original_url may differ, so it is configurable.
      def valid_signature?(signature)
        return false if signature.blank?

        key = Pay::Square.signing_secret
        return false if key.blank?

        data = notification_url + request.raw_post
        digest = OpenSSL::Digest.new("sha256")
        hmac = Base64.strict_encode64(OpenSSL::HMAC.digest(digest, key, data))
        ActiveSupport::SecurityUtils.secure_compare(hmac, signature)
      end

      def notification_url
        Pay::Square.webhook_notification_url.presence || request.original_url
      end

      def verify_params
        params.except(:action, :controller).permit!
      end
    end
  end
end
