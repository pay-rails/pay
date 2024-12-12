module Pay
  module AwsMarketplace
    class Charge < Pay::Charge
      def api_record
        self
      end

      def refund!(amount_to_refund = nil)
        update(amount_refunded: amount_to_refund || amount)
      end
    end
  end
end
