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

        user = User.find_by(processor: :braintree, processor_id: subscription.id)
        return unless user.present?

        payment_method = Pay.braintree_gateway.payment_method.find(subscription.payment_method_token)

        charge = user.charges.new(amount: subscription.price * 100)
        case payment_method.class
        when Braintree::CreditCard, Braintree::ApplePayCard, Braintree::VisaCheckoutCard, Braintree::MasterpassCard, Braintree::SamsungPayCard
          charge.assign_attributtes(
            card_type:      payment_method.card_type,
            card_last4:     payment_method.last_4,
            card_exp_month: payment_method.expiration_month,
            card_exp_year:  payment_method.expiration_year,
          )
        when Braintree::PayPalAccount
          charge.assign_attributtes(
            card_type: "PayPal",
            card_last4: payment_method.email,
          )
        when Braintree::AndroidPayCard
          charge.assign_attributtes(
            card_type:      payment_method.source_card_type,
            card_last4:     payment_method.source_card_last_4,
            card_exp_month: payment_method.expiration_month,
            card_exp_year:  payment_method.expiration_year,
          )
        when Braintree::VenmoAccount
          charge.assign_attributtes(
            card_type:  "Venmo",
            card_last4: payment_method.username,
          )
        end

        charge.save!
      end

      def subscription_canceled(event)
        subscription = event.subscription
        return if subscription.nil?

        user = User.find_by(processor: :braintree, processor_id: subscription.id)
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
