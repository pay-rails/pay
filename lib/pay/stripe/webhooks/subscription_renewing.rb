module Pay
  module Stripe
    module Webhooks
      class SubscriptionRenewing
        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object
          subscription = Pay.subscription_model.find_by(
            processor: :stripe,
            processor_id: event.data.object.subscription
          )
          date = Time.zone.at(event.data.object.next_payment_attempt)
          notify_user(subscription.owner, subscription, date) if subscription.present?
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
