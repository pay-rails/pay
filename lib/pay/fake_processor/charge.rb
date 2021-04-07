module Pay
  module FakeProcessor
    class Charge
      attr_reader :pay_charge

      delegate :processor_id, :owner, to: :pay_charge

      def initialize(pay_charge)
        @pay_charge = pay_charge
      end

      def charge
        pay_charge
      end

      def refund!(amount_to_refund)
        pay_charge.update(amount_refunded: amount_to_refund)
      end
    end
  end
end
