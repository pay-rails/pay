module Pay
  module FakeProcessor
    class Charge < Pay::Charge
      def self.sync(processor_id)
        true
      end

      def api_record
        self
      end

      def refund!(amount_to_refund = nil)
        update(amount_refunded: amount_to_refund || amount)
      end
    end
  end
end
