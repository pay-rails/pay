module Pay
  module Stripe
    module Webhooks
      class PaymentActionRequired
        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object

          object = event.data.object

          subscription = Pay.subscription_model.find_by(processor: :stripe, processor_id: object.subscription)
          return if subscription.nil?
          billable = subscription.owner

          notify_user(billable, event.data.object.payment_intent, subscription)
        end

        def notify_user(billable, payment_intent_id, subscription)
          if Pay.send_emails
            Pay::UserMailer.with(billable: billable, payment_intent_id: payment_intent_id, subscription: subscription).payment_action_required.deliver_later
          end
        end
      end
    end
  end
end
