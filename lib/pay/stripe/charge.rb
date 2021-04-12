module Pay
  module Stripe
    class Charge
      attr_reader :pay_charge

      delegate :processor_id, :owner, :stripe_account, to: :pay_charge

      def initialize(pay_charge)
        @pay_charge = pay_charge
      end

      def charge
        ::Stripe::Charge.retrieve({id: processor_id, expand: ["customer", "invoice.subscription"]}, {stripe_account: stripe_account})
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # https://stripe.com/docs/api/refunds/create
      #
      # refund!
      # refund!(5_00)
      # refund!(5_00, refund_application_fee: true)
      def refund!(amount_to_refund, **options)
        ::Stripe::Refund.create(options.merge(charge: processor_id, amount: amount_to_refund), {stripe_account: stripe_account})
        pay_charge.update(amount_refunded: amount_to_refund)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end
    end
  end
end
