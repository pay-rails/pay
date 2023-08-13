module Pay
  module Paddle
    module Webhooks
      class TransactionCompleted
        def call(event)
          pay_customer = Pay::Customer.find_by(processor: :paddle, processor_id: event.customer_id)

          if pay_customer.nil?
            owner = Pay::Paddle.owner_from_passthrough(event.custom_data.passthrough)
            pay_customer = owner&.set_payment_processor :paddle, processor_id: event.customer_id
          end

          if pay_customer.nil?
            Rails.logger.error("[Pay] Unable to find Pay::Customer with: '#{event.passthrough}'")
            return
          end

          return if pay_customer.charges.where(processor_id: event.id).any?

          pay_charge = create_charge(pay_customer, event)
          notify_user(pay_charge)
        end

        def create_charge(pay_customer, event)
          item = event.items.first
          payment = event.payments.first

          if payment.method_details.type == "card"
            card = payment.method_details.card
            payment_method_details = {
              payment_method_type: :card,
              brand: card[:type],
              last4: card[:last4],
              exp_month: card[:expiry_month],
              exp_year: card[:expiry_year]
            }
          else
            payment_method_details = {}
          end


          price = item.price.unit_price
          attributes = {
            amount: (price.amount.to_f / 100),
            created_at: event.created_at,
            currency: price.currency_code,
          }.merge(payment_method_details)

          pay_charge = pay_customer.charges.find_or_initialize_by(processor_id: event.id)
          pay_charge.update!(attributes)

          # Update customer's payment method
          Pay::Paddle::PaymentMethod.sync(pay_customer: pay_customer, attributes: payment_method_details)

          pay_charge
        end

        def notify_user(pay_charge)
          if Pay.send_email?(:receipt, pay_charge)
            Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
