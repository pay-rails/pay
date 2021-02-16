module Pay
  module Stripe
    module Webhooks
      class ChargeSucceeded
        def call(event)
          object = event.data.object
          billable = Pay.find_billable(processor: :stripe, processor_id: object.customer)

          return unless billable.present?
          return if billable.charges.where(processor_id: object.id).any?

          charge = Pay::Stripe::Billable.new(billable).save_pay_charge(object)
          notify_user(billable, charge)
        end

        def notify_user(billable, charge)
          if Pay.send_emails && charge.respond_to?(:receipt)
            Pay::UserMailer.with(billable: billable, charge: charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
