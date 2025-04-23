module Pay
  module Stripe
    module Webhooks
      class SubscriptionRenewing
        # Handles `invoice.upcoming` webhook from Stripe
        # Occurs X number of days before a subscription is scheduled to create an invoice that is automatically charged—where X is determined by your subscriptions settings. Note: The received Invoice object will not have an invoice ID.

        def call(event)
          invoice = event.data.object
          subscription_id = invoice.parent.try(:subscription_details).try(:subscription)

          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object
          pay_subscription = Pay::Subscription.find_by_processor_and_id(:stripe, subscription_id)
          return unless pay_subscription

          # Stripe subscription items all have the same interval
          price = ::Stripe::Price.retrieve(invoice.lines.first.pricing.price_details.price)

          # For collection_method=send_invoice, Stripe will send an email and next_payment_attempt will be null
          # https://docs.stripe.com/api/invoices/object#invoice_object-collection_method
          if Pay.send_email?(:subscription_renewing, pay_subscription, price) && (next_payment_attempt = invoice.next_payment_attempt)
            Pay.mailer.with(
              pay_customer: pay_subscription.customer,
              pay_subscription: pay_subscription,
              date: Time.zone.at(next_payment_attempt)
            ).subscription_renewing.deliver_later
          end
        end
      end
    end
  end
end
