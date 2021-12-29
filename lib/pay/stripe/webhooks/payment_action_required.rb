module Pay
  module Stripe
    module Webhooks
      class PaymentActionRequired
        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object

          object = event.data.object

          subscription = Pay::Subscription.find_by_processor_and_id(:stripe, object.subscription)
          return if subscription.nil?

          if Pay.send_emails
            Pay::UserMailer.with(
              pay_customer: subscription.customer,
              payment_intent_id: event.data.object.payment_intent,
              subscription: subscription
            ).payment_action_required.deliver_later
          end
        end
      end
    end
  end
end
