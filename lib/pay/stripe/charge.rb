module Pay
  module Stripe
    class Charge
      attr_reader :pay_charge

      delegate :processor_id, :owner, to: :pay_charge

      def initialize(pay_charge)
        @pay_charge = pay_charge
      end

      def charge
        ::Stripe::Charge.retrieve(processor_id)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def refund!(amount_to_refund)
        ::Stripe::Refund.create(charge: processor_id, amount: amount_to_refund)
        pay_charge.update(amount_refunded: amount_to_refund)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end
    end
  end
end
