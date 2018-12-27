module Pay
  module Stripe

    module Charge
      extend ActiveSupport::Concern

      def stripe_charge
        Stripe::Charge.retrieve(processor_id)
      end

      def stripe_refund!(amount)
        Stripe::Refund.create(
          charge: processor_id,
          amount: amount
        )

        update(amount_refunded: amount)
      end
    end

  end
end
