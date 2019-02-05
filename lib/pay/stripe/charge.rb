module Pay
  module Stripe

    module Charge
      extend ActiveSupport::Concern

      def stripe_charge
        Stripe::Charge.retrieve(processor_id)
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      def stripe_refund!(amount)
        Stripe::Refund.create(
          charge: processor_id,
          amount: amount
        )

        update(amount_refunded: amount)
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end
    end

  end
end
