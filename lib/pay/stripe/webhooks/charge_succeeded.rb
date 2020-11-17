module Pay
  module Stripe
    module Webhooks
      class ChargeSucceeded
        def call(event)
          object = event.data.object
          billable = Pay.find_billable(processor: :stripe, processor_id: object.customer)

          return unless billable.present?
          return if billable.charges.where(processor_id: object.id).any?

          create_charge(billable, object)
        end

        def create_charge(billable, object)
          charge = billable.charges.find_or_initialize_by(
            processor: :stripe,
            processor_id: object.id
          )

          charge.update(
            amount: object.amount,
            card_last4: object.payment_method_details.card.last4,
            card_type: object.payment_method_details.card.brand,
            card_exp_month: object.payment_method_details.card.exp_month,
            card_exp_year: object.payment_method_details.card.exp_year,
            created_at: Time.zone.at(object.created)
          )

          notify_user(billable, charge)

          charge
        end

        def notify_user(billable, charge)
          if Pay.send_emails && charge.respond_to?(:receipt)
            Pay::UserMailer.receipt(billable, charge).deliver_later
          end
        end
      end
    end
  end
end
