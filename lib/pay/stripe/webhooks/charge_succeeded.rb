module Pay
  module Stripe
    module Webhooks
      class ChargeSucceeded
        def call(event)
          object = event.data.object
          user = Pay.user_model.find_by(
            processor: :stripe,
            processor_id: object.customer
          )

          return unless user.present?
          return if user.charges.where(processor_id: object.id).any?

          charge = create_charge(user, object)
          notify_user(user, charge)
          charge
        end

        def create_charge(user, object)
          charge = user.charges.find_or_initialize_by(
            processor: :stripe,
            processor_id: object.id,
          )

          charge.update(
            amount: object.amount,
            card_last4: object.payment_method_details.card.last4,
            card_type: object.payment_method_details.card.brand,
            card_exp_month: object.payment_method_details.card.exp_month,
            card_exp_year: object.payment_method_details.card.exp_year,
            created_at: Time.zone.at(object.created)
          )

          charge
        end

        def notify_user(user, charge)
          if Pay.send_emails && charge.respond_to?(:receipt)
            Pay::UserMailer.receipt(user, charge).deliver_later
          end
        end
      end
    end
  end
end
