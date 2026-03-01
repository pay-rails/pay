# frozen_string_literal: true

module Pay
  module Webhooks
    class PayTheFlyController < ActionController::API
      def create
        payload = request.raw_post
        event = JSON.parse(payload)

        if valid_signature?(event)
          queue_event(event)
          # PayTheFly requires response body to contain "success"
          render json: {status: "success"}
        else
          head :bad_request
        end
      rescue JSON::ParserError
        head :bad_request
      rescue Pay::PayTheFly::Error
        head :bad_request
      end

      private

      def queue_event(event)
        data = JSON.parse(event["data"])
        event_type = determine_event_type(data)

        return unless Pay::Webhooks.delegator.listening?("pay_the_fly.#{event_type}")

        record = Pay::Webhook.create!(
          processor: :pay_the_fly,
          event_type: event_type,
          event: data
        )
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      # Determine event type from tx_type field
      # tx_type: 1 = payment, 2 = withdrawal
      def determine_event_type(data)
        case data["tx_type"].to_i
        when 1 then "payment_confirmed"
        when 2 then "withdrawal_confirmed"
        else "unknown"
        end
      end

      # Verify HMAC-SHA256 webhook signature
      # Sign = HMAC-SHA256(data + "." + timestamp, projectKey)
      def valid_signature?(event)
        data = event["data"]
        timestamp = event["timestamp"]
        signature = event["sign"]

        return false if data.blank? || timestamp.blank? || signature.blank?

        Pay::PayTheFly.verify_webhook_signature(
          data: data,
          timestamp: timestamp,
          signature: signature
        )
      end
    end
  end
end
