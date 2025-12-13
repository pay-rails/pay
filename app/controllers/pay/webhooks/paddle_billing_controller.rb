module Pay
  module Webhooks
    class PaddleBillingController < Pay::ApplicationController
      skip_forgery_protection if Rails.application.config.action_controller.default_protect_from_forgery

      def create
        if valid_signature?(request.headers['Paddle-Signature'])
          queue_event(verify_params.as_json)
          head :ok
        else
          head :bad_request
        end
      rescue Pay::PaddleBilling::Error
        head :bad_request
      end

      private

      def queue_event(event)
        return unless Pay::Webhooks.delegator.listening?("paddle_billing.#{params[:event_type]}")

        record = Pay::Webhook.create!(processor: :paddle_billing, event_type: params[:event_type], event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      # Pass Paddle signature from request.headers["Paddle-Signature"]
      def valid_signature?(paddle_signature)
        return false if paddle_signature.blank?

        ts_part, h1_part = paddle_signature.split(';')
        _, ts = ts_part.split('=')
        _, h1 = h1_part.split('=')

        signed_payload = "#{ts}:#{request.raw_post}"

        key = Pay::PaddleBilling.signing_secret
        data = signed_payload
        digest = OpenSSL::Digest.new('sha256')

        hmac = OpenSSL::HMAC.hexdigest(digest, key, data)
        hmac == h1
      end

      def verify_params
        params.except(:action, :controller).permit!
      end
    end
  end
end
