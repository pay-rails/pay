module Pay
  module Webhooks
    class BraintreeController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        case verified_event.kind
        when "subscription_charged_successfully"
          subscription_charged_successfully(verified_event)
        when "subscription_canceled"
          subscription_canceled(verified_event)
        end

        render json: {success: true}
      rescue Braintree::InvalidSignature => e
        head :ok
      end

      private

      def subscription_charged_successfully(event)
        subscription = event.subscription
        return if subscription.nil?

        user = Pay.user_model.find_by(processor: :braintree, processor_id: subscription.id)
        return unless user.present?

        charge = user.save_braintree_transaction(subscription.transactions.first)

        if Pay.send_emails
          Pay::UserMailer.receipt(user, charge).deliver_later
        end
      end

      def subscription_canceled(event)
        subscription = event.subscription
        return if subscription.nil?

        user = Pay.user_model.find_by(processor: :braintree, processor_id: subscription.id)
        return unless user.present?

        # User canceled or failed to make payments
        user.update(braintree_subscription_id: nil)
      end

      def verified_webhook
        @webhook_notification ||= Braintree::WebhookNotification.parse(
          params[:bt_signature],
          params[:bt_payload]
        )
      end
    end
  end
end
