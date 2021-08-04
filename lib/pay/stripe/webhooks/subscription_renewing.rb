module Pay
  module Stripe
    module Webhooks
      class SubscriptionRenewing
        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object
          subscription = Pay::Subscription.find_by_processor_and_id(:stripe, event.data.object.subscription)
          return unless subscription

          notify_user(subscription.customer.owner, subscription, Time.zone.at(event.data.object.next_payment_attempt))
        end

        def notify_user(billable, subscription, date)
          if Pay.send_emails
            Pay::UserMailer.with(billable: billable, subscription: subscription, date: date).subscription_renewing.deliver_later
          end
        end
      end
    end
  end
end
