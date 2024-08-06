module Pay
  module Webhooks
    class LemonSqueezyController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        if valid_signature?(request.headers["X-Signature"])
          queue_event(verify_params.as_json)
          head :ok
        else
          head :bad_request
        end
      rescue Pay::LemonSqueezy::Error
        head :bad_request
      end

      private

      def queue_event(event)
        return unless Pay::Webhooks.delegator.listening?("lemon_squeezy.#{params[:meta][:event_name]}")

        record = Pay::Webhook.create!(processor: :lemon_squeezy, event_type: params[:meta][:event_name], event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      # Pass Lemon Squeezy signature from request.headers["X-Signature"]
      def valid_signature?(signature)
        return false if signature.blank?

        key = Pay::LemonSqueezy.signing_secret
        data = request.raw_post
        digest = OpenSSL::Digest.new("sha256")

        hmac = OpenSSL::HMAC.hexdigest(digest, key, data)
        ActiveSupport::SecurityUtils.secure_compare(hmac, signature)
      end

      def verify_params
        params.except(:action, :controller).permit!
      end
    end
  end
end
