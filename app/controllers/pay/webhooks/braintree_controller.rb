module Pay
  module Webhooks
    class BraintreeController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        case webhook_notification.kind
        when "subscription_charged_successfully"
          subscription_charged_successfully(webhook_notification)
        when "subscription_canceled"
          subscription_canceled(webhook_notification)
        when "subscription_trial_ended"
          subscription_trial_ended(webhook_notification)
        end

        render json: {success: true}, status: :ok
      rescue ::Braintree::InvalidSignature => e
        head :ok
      end

      private

      def subscription_charged_successfully(event)
        subscription = event.subscription
        return if subscription.nil?

        pay_subscription = Pay.subscription_model.find_by(processor: :braintree, processor_id: subscription.id)
        return unless pay_subscription.present?

        user = pay_subscription.owner
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

      def subscription_trial_ended(event)
        subscription = event.subscription
        return if subscription.nil?

        pay_subscription = Pay.subscription_model.find_by(processor: :braintree, processor_id: subscription.id)
        return unless pay_subscription.present?

        pay_subscription.update(trial_ends_at: Time.zone.now)
      end

      def webhook_notification
        @webhook_notification ||= Pay.braintree_gateway.webhook_notification.parse(
          params[:bt_signature],
          params[:bt_payload]
        )
      end
    end
  end
end
