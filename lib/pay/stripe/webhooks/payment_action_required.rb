module Pay
  module Stripe
    module Webhooks
      class PaymentActionRequired
        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object

          user = event.data.object.customer

          subscription = Pay.subscription_model.find_by(
            processor: :stripe,
            processor_id: event.data.object.subscription
          )

          notify_user(user, event.data.object.payment_intent, subscription)
        end

        def notify_user(user, payment_intent_id, subscription)
          if Pay.send_emails
            Pay::UserMailer.payment_action_required(user, payment_intent_id, subscription).deliver_later
          end
        end
      end
    end
  end
end
