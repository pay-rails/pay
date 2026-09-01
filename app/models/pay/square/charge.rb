module Pay
  module Square
    class Charge < Pay::Charge
      store_accessor :data, :square_order_id
      store_accessor :data, :square_status
      store_accessor :data, :square_merchant_id

      # Re-fetches authoritative payment state (webhook delivery is unordered), unless a
      # freshly created payment is passed in.
      def self.sync(payment_id, object: nil, pay_customer: nil, try: 0, retries: 1)
        object ||= Pay::Square.with_client(pay_customer) { |client| client.payments.get(payment_id: payment_id) }.payment
        return if object.nil?

        pay_customer ||= Pay::Customer.find_by(processor: :square, processor_id: object.customer_id)
        if pay_customer.nil?
          Rails.logger.debug "Pay::Customer for Square payment #{payment_id} (customer #{object.customer_id}) is not in the database"
          return
        end

        card = object.card_details&.card
        attrs = {
          amount: object.amount_money&.amount,
          currency: object.amount_money&.currency&.downcase,
          application_fee_amount: object.app_fee_money&.amount,
          amount_refunded: object.refunded_money&.amount || 0,
          payment_method_type: "card",
          brand: card&.card_brand,
          last4: card&.last_4.to_s,
          exp_month: card&.exp_month&.to_s,
          exp_year: card&.exp_year&.to_s,
          square_account: pay_customer.square_account,
          square_order_id: object.order_id,
          square_status: object.status,
          square_merchant_id: (object.respond_to?(:merchant_id) ? object.merchant_id : nil)
        }
        attrs[:created_at] = Time.zone.parse(object.created_at.to_s) if object.respond_to?(:created_at) && object.created_at.present?

        if (pay_charge = find_by(customer: pay_customer, processor_id: object.id))
          pay_charge.with_lock { pay_charge.update!(attrs) }
          pay_charge
        else
          create!(attrs.merge(customer: pay_customer, processor_id: object.id))
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        if try >= retries
          raise
        else
          sleep 0.15**(try + 1)
          retry_args = {object: object, pay_customer: pay_customer, try: try + 1, retries: retries}
          sync(payment_id, **retry_args)
        end
      end

      def api_record
        Pay::Square.with_client(customer) { |client| client.payments.get(payment_id: processor_id) }.payment
      end

      # Square refunds are asynchronous (PENDING -> COMPLETED, can fail), so re-sync
      # amount_refunded from the payment rather than optimistically incrementing.
      def refund!(amount_to_refund = nil, **options)
        amount_to_refund ||= amount
        idempotency_key = options.delete(:idempotency_key) || SecureRandom.uuid

        Pay::Square.with_client(customer) do |client|
          client.refunds.refund_payment(
            idempotency_key: idempotency_key,
            payment_id: processor_id,
            amount_money: {amount: amount_to_refund, currency: (currency || "usd").to_s.upcase}
          )
        end

        self.class.sync(processor_id, pay_customer: customer)
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_square_charge, Pay::Square::Charge
