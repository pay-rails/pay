module Pay
  module Btcpay
    class Subscription < Pay::Subscription
      store_accessor :data, :status, :renewal_instructions

      def self.sync(processor_id)
        subscription = find_by(processor_id: processor_id)
        return if subscription.nil?

        subscription.update(data: Pay::Btcpay.client.get_payment_request(processor_id))
        subscription
      end

      def api_record
        @api_record ||= Pay::Btcpay.client.get_payment_request(processor_id)
      end

      def cancel(args = {})
        # Update payment request to archived/inactive
        Pay::Btcpay.client.update_payment_request(processor_id, {
                                                    archived: true
                                                  })

        super
      end

      def cancel_now!
        cancel
      end

      def pause
        # Pause by archiving the payment request
        Pay::Btcpay.client.update_payment_request(processor_id, {
                                                    archived: true
                                                  })

        update(paused_at: Time.current)
      end

      def resume
        # Resume by unarchiving the payment request
        Pay::Btcpay.client.update_payment_request(processor_id, {
                                                    archived: false
                                                  })

        update(paused_at: nil, ends_at: nil)
      end

      def swap(plan, params = {})
        # For BTCPay, swapping means updating the payment request with new amount
        new_amount = params[:amount] || plan.amount

        Pay::Btcpay.client.update_payment_request(processor_id, {
                                                    price: (new_amount.to_f / 100).to_s
                                                  })

        update(
          plan_id: plan.is_a?(String) ? plan : plan.id,
          quantity: params[:quantity] || quantity,
          amount: new_amount
        )
      end

      def on_trial?
        trial_ends_at.present? && trial_ends_at > Time.current
      end

      def active?
        !paused_at? && !ends_at? && !cancelled_at? ||
          (ends_at.present? && ends_at > Time.current)
      end
    end
  end
end
