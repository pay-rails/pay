# frozen_string_literal: true
module Pay
  module Btcpay
    class Charge < Pay::Charge
      store_accessor :data, :status, :amount_received, :expiration_time

      def self.sync(processor_id)
        charge = find_by(processor_id: processor_id)
        return if charge.nil?

        charge.update(data: Pay::Btcpay.client.get_invoice(processor_id))
        charge
      end

      def api_record
        @api_record ||= Pay::Btcpay.client.get_invoice(processor_id)
      end

      def refund!(amount_in_cents = nil, params = {})
        # BTCPay invoices can't be refunded through the API
        # Refunds must be done manually or through the merchant's wallet
        raise NotImplementedError, 'BTCPay does not support automatic refunds. Please process refunds manually.'
      end

      def charged?
        api_record['status'] == 'settled' || api_record['exceptionStatus'] == 'paidOver'
      end

      def failed?
        api_record['status'] == 'expired' || api_record['exceptionStatus'] == 'paidLate'
      end
    end
  end
end
