module Pay
  module Btcpay
    class PaymentMethod < Pay::PaymentMethod
      store_accessor :data, :wallet_address, :payment_method_type

      def self.sync(processor_id)
        payment_method = find_by(processor_id: processor_id)
        return if payment_method.nil?

        # BTCPay doesn't store payment methods like other processors
        # This is a placeholder for wallet/address sync if needed
        payment_method
      end

      def api_record
        # BTCPay doesn't have a payment method API endpoint
        # Return the data stored in the database
        data
      end

      def default?
        default
      end

      def mark_default!
        # Mark this payment method as default for the customer
        customer.payment_methods.update_all(default: false)
        update(default: true)
      end
    end
  end
end
