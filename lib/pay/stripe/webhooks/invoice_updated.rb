module Pay
  module Stripe
    module Webhooks
      class InvoiceUpdated
        def call(event)
          # Grab the invoice from the event
          invoice = event.data.object

          # Find the corresponding subscription_id
          subscription_id = invoice.parent.try(:subscription_details).try(:subscription)

          # Not all invoices have a subscription - could be a one-time or manual payment
          return if subscription_id.blank?

          # Grab the local subscription
          subscription = Pay::Subscription.find_by_processor_and_id(:stripe, subscription_id)

          # Return if we don't have a corresponding subscription
          return unless subscription

          # Grab the local latest_invoice from the subscription stripe_object
          latest_invoice = subscription.stripe_object.try(:latest_invoice)

          # Compare the local invoice id to the event invoice id and sync if they are the same
          if latest_invoice.id.to_s == invoice.id.to_s
            Pay::Stripe::Subscription.sync(subscription_id, stripe_account: event.try(:account))
          end
        rescue ::Stripe::StripeError => e
          Rails.logger.error "Stripe Webhook Error (InvoiceUpdated): #{e.message}"
        end
      end
    end
  end
end
