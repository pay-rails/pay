module Pay
  module Stripe
    module Webhooks
      class SubscriptionRenewing
        # Handles `invoice.upcoming` webhook from Stripe
        # Occurs X number of days before a subscription is scheduled to create an invoice that is automatically charged—where X is determined by your subscriptions settings. Note: The received Invoice object will not have an invoice ID.

        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object
          pay_subscription = Pay::Subscription.find_by_processor_and_id(:stripe, event.data.object.subscription)
          return unless pay_subscription

          # Stripe subscription items all have the same interval
          price = event.data.object.lines.data.first.price

          if Pay.send_email?(:subscription_renewing, pay_subscription, price)
            Pay.mailer.with(
              pay_customer: pay_subscription.customer,
              pay_subscription: pay_subscription,
              date: Time.zone.at(event.data.object.next_payment_attempt)
            ).subscription_renewing.deliver_later
          end
        end
      end
    end
  end
end
