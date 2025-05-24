module Pay
  module PaddleClassic
    module Webhooks
      class SubscriptionPaymentSucceeded
        def call(event)
          pay_customer = Pay::Customer.find_by(processor: :paddle_classic, processor_id: event.user_id)

          if pay_customer.nil?
            owner = Pay::PaddleClassic.owner_from_passthrough(event.passthrough)
            pay_customer = owner&.set_pay_payment_processor :paddle_classic, processor_id: event.user_id
          end

          if pay_customer.nil?
            Rails.logger.error("[Pay] Unable to find Pay::Customer with: '#{event.passthrough}'")
            return
          end

          return if pay_customer.pay_charges.where(processor_id: event.subscription_payment_id).any?

          pay_charge = create_charge(pay_customer, event)
          notify_user(pay_charge)
        end

        def create_charge(pay_customer, event)
          payment_method_details = Pay::PaddleClassic::PaymentMethod.payment_method_details_for(subscription_id: event.subscription_id)

          attributes = {
            amount: (event.sale_gross.to_f * 100).to_i,
            created_at: Time.zone.parse(event.event_time),
            currency: event.currency,
            paddle_receipt_url: event.receipt_url,
            subscription: pay_customer.pay_subscriptions.find_by(processor_id: event.subscription_id),
            metadata: Pay::PaddleClassic.parse_passthrough(event.passthrough).except("owner_sgid")
          }.merge(payment_method_details)

          pay_charge = pay_customer.pay_charges.find_or_initialize_by(processor_id: event.subscription_payment_id)
          pay_charge.update!(attributes)

          # Update customer's payment method
          Pay::PaddleClassic::PaymentMethod.sync(pay_customer: pay_customer, attributes: payment_method_details)

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
