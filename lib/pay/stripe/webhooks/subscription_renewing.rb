module Pay
  module Stripe
    module Webhooks
      class SubscriptionRenewing
        # Handles `invoice.upcoming` webhook from Stripe
        # Occurs X number of days before a subscription is scheduled to create an invoice that is automatically charged—where X is determined by your subscriptions settings. Note: The received Invoice object will not have an invoice ID.

        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object
          subscription = Pay::Subscription.find_by_processor_and_id(:stripe, event.data.object.subscription)
          return unless subscription

          # Stripe subscription items all have the same interval
          price = event.data.object.lines.data.first.price
          return unless price.type == "recurring"

          interval = price.recurring.interval
          return unless interval == "year"

          if Pay.send_emails
            Pay::UserMailer.with(
              pay_customer: subscription.customer,
              subscription: subscription,
              date: Time.zone.at(event.data.object.next_payment_attempt)
            ).subscription_renewing.deliver_later
          end
        end
      end
    end
  end
end
