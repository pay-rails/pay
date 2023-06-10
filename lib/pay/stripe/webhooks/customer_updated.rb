module Pay
  module Stripe
    module Webhooks
      class CustomerUpdated
        def call(event)
          object = event.data.object
          pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.id)

          # Couldn't find user, we can skip
          return unless pay_customer.present?

          payment_customer = pay_customer.customer

          # Sync default card
          if (payment_method_id = payment_customer.invoice_settings.default_payment_method)
            Pay::Stripe::PaymentMethod.sync(payment_method_id, stripe_account: event.try(:account))

          else
            # No default payment method set
            pay_customer.payment_methods.update_all(default: false)
          end

          # Sync invoice credit balance and currency
          if payment_customer.invoice_credit_balance&.keys.present?
            pay_customer.update(invoice_credit_balance: payment_customer.invoice_credit_balance[payment_customer.currency], currency: payment_customer.currency)
          end
        end
      end
    end
  end
end
