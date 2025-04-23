module Pay
  module Stripe
    module Webhooks
      class PaymentActionRequired
        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object

          invoice = event.data.object
          subscription_id = invoice.parent.try(:subscription_details).try(:subscription)

          # Don't send email on incomplete Stripe subscriptions since they're just getting created and the JavaScript will handle SCA
          pay_subscription = Pay::Subscription.find_by_processor_and_id(:stripe, subscription_id)
          return if pay_subscription.nil? || pay_subscription.status == "incomplete"

          if Pay.send_email?(:payment_action_required, pay_subscription)
            Pay.mailer.with(
              pay_customer: pay_subscription.customer,
              payment_intent_id: invoice.payment_intent,
              pay_subscription: pay_subscription
            ).payment_action_required.deliver_later
          end
        end
      end
    end
  end
end
