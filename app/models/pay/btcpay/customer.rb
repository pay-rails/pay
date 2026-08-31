module Pay
  module Btcpay
    class Customer < Pay::Customer
      store_accessor :data, :btcpay_customer_id

      def api_record
        @api_record ||= btcpay_customer_id
      end

      def api_record_attributes
        {
          email: owner.email,
          metadata: {
            owner_id: owner.id,
            owner_type: owner.class.name
          }
        }
      end

      def charge(amount, params = {})
        # Create a one-time invoice
        invoice_params = {
          amount: (amount.to_f / 100).to_s,
          currency: params[:currency] || 'USD',
          orderId: params[:order_id] || SecureRandom.hex(12),
          buyerEmail: params[:email] || owner.email,
          metadata: {
            customer_id: id,
            owner_id: owner.id,
            owner_type: owner.class.name
          }
        }

        invoice_params.merge!(params.slice(:description, :notificationURL, :redirectURL, :posData))

        invoice = Pay::Btcpay.client.create_invoice(invoice_params)

        Pay::Charge.create!(
          customer: self,
          amount: amount,
          currency: params[:currency] || 'USD',
          description: params[:description],
          processor: 'btcpay',
          processor_id: invoice['id'],
          data: invoice
        )
      end

      def add_payment_method(token, params = {})
        # BTCPay doesn't use payment method tokens like Stripe
        # Instead, store wallet address or payment request reference
        Pay::PaymentMethod.create!(
          customer: self,
          processor: 'btcpay',
          processor_id: token,
          data: params
        )
      end

      def payment_methods
        super.where(processor: 'btcpay')
      end

      def subscribe(name, params = {})
        # Create a payment request for recurring payments
        payment_request_params = {
          title: name,
          description: params[:description],
          price: (params[:amount].to_f / 100).to_s,
          currency: params[:currency] || 'USD',
          allowCustomPaymentAmounts: false,
          email: owner.email,
          successUrl: params[:success_url],
          expiredUrl: params[:expired_url],
          notificationURL: params[:notification_url]
        }

        request = Pay::Btcpay.client.create_payment_request(payment_request_params)

        Pay::Subscription.create!(
          customer: self,
          name: name,
          processor: 'btcpay',
          processor_id: request['id'],
          plan_id: params[:plan_id] || name,
          quantity: params[:quantity] || 1,
          currency: params[:currency] || 'USD',
          period: params[:period] || 'month',
          interval_count: params[:interval_count] || 1,
          amount: params[:amount],
          data: request,
          paddle_update_url: request['url'],
          trial_ends_at: params[:trial_period_days] ? Time.current + params[:trial_period_days].days : nil,
          ends_at: params[:expires_at]
        )
      end

      def update_payment_method(token, params = {})
        # Update payment method/wallet address
        payment_method = payment_methods.where(processor_id: token).first

        if payment_method
          payment_method.update(data: params)
        else
          add_payment_method(token, params)
        end
      end
    end
  end
end
