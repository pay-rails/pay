module Pay
  module Webhooks
    class Btcpay
      def self.handle(event, payload)
        case event['type']
        when 'InvoiceCreated'
          handle_invoice_created(payload)
        when 'InvoiceReceivedPayment'
          handle_invoice_received_payment(payload)
        when 'InvoicePaymentSettled'
          handle_invoice_payment_settled(payload)
        when 'InvoiceExpired'
          handle_invoice_expired(payload)
        when 'PaymentRequestReceived'
          handle_payment_request_received(payload)
        when 'PaymentRequestExpired'
          handle_payment_request_expired(payload)
        end
      end

      private

      def self.handle_invoice_created(payload)
        # Invoice was created - no action needed yet
      end

      def self.handle_invoice_received_payment(payload)
        # Payment received, but may not be fully confirmed
        invoice_id = payload.dig('data', 'id')
        charge = Pay::Charge.find_by(processor_id: invoice_id, processor: 'btcpay')

        return unless charge

        # Update charge data
        charge.update(
          data: Pay::Btcpay.client.get_invoice(invoice_id)
        )

        Pay.instrument('btcpay.payment_received', charge: charge)
      end

      def self.handle_invoice_payment_settled(payload)
        # Payment fully settled and confirmed
        invoice_id = payload.dig('data', 'id')
        charge = Pay::Charge.find_by(processor_id: invoice_id, processor: 'btcpay')

        return unless charge

        # Update charge data
        invoice_data = Pay::Btcpay.client.get_invoice(invoice_id)
        charge.update(
          data: invoice_data,
          amount_received: (invoice_data['amountReceived'].to_f * 100).to_i
        )

        # Mark as charged
        charge.update_columns(charged_at: Time.current) if charge.charged_at.nil?

        Pay.instrument('btcpay.charge.completed', charge: charge)
      end

      def self.handle_invoice_expired(payload)
        # Invoice/payment expired
        invoice_id = payload.dig('data', 'id')
        charge = Pay::Charge.find_by(processor_id: invoice_id, processor: 'btcpay')

        return unless charge

        charge.update(
          data: Pay::Btcpay.client.get_invoice(invoice_id)
        )

        Pay.instrument('btcpay.charge.failed', charge: charge)
      end

      def self.handle_payment_request_received(payload)
        # Payment request payment received
        request_id = payload.dig('data', 'id')
        subscription = Pay::Subscription.find_by(processor_id: request_id, processor: 'btcpay')

        return unless subscription

        subscription.update(
          data: Pay::Btcpay.client.get_payment_request(request_id)
        )

        Pay.instrument('btcpay.subscription.payment_received', subscription: subscription)
      end

      def self.handle_payment_request_expired(payload)
        # Payment request expired
        request_id = payload.dig('data', 'id')
        subscription = Pay::Subscription.find_by(processor_id: request_id, processor: 'btcpay')

        return unless subscription

        subscription.update(
          data: Pay::Btcpay.client.get_payment_request(request_id),
          ended_at: Time.current
        )

        Pay.instrument('btcpay.subscription.expired', subscription: subscription)
      end
    end
  end
end
