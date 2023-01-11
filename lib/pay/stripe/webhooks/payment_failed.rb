module Pay
  module Stripe
    module Webhooks
      class PaymentFailed
        def call(event)
          # Event is of type "invoice" see:
          # https://stripe.com/docs/api/invoices/object

          object = event.data.object

          pay_subscription = Pay::Subscription.find_by_processor_and_id(:stripe, object.subscription)
          return if pay_subscription.nil?

          if Pay.send_email?(:payment_failed, pay_subscription)
            Pay.mailer.with(
              pay_customer: pay_subscription.customer,
              stripe_invoice: object
            ).payment_failed.deliver_now
          end
        end
      end
    end
  end
end
