module Pay
  module Stripe
    module Webhooks
      class CustomerUpdated
        def call(event)
          object = event.data.object
          pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.id)

          # Couldn't find user, we can skip
          return unless pay_customer.present?

          customer = pay_customer.customer
          payment_method_id = customer.invoice_settings.default_payment_method || customer.default_source

          # Sync default card
          if payment_method_id
            Pay::Stripe::PaymentMethod.sync(payment_method_id, stripe_account: event.try(:account))

          else
            # No default payment method set
            pay_customer.payment_methods.update_all(default: false)
          end
        end
      end
    end
  end
end
