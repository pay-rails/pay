module Pay
  module Stripe
    module Webhooks
      class PaymentActionRequired
        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object

          object = event.data.object

          pay_subscription = Pay::Subscription.find_by_processor_and_id(:stripe, object.subscription)
          return if pay_subscription.nil?

          if Pay.send_email?(:payment_action_required, pay_subscription)
            Pay.mailer.with(
              pay_customer: pay_subscription.customer,
              payment_intent_id: event.data.object.payment_intent,
              pay_subscription: pay_subscription
            ).payment_action_required.deliver_later
          end
        end
      end
    end
  end
end
