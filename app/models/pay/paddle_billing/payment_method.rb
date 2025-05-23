module Pay
  module PaddleBilling
    class PaymentMethod < Pay::PaymentMethod
      def self.sync_from_transaction(pay_customer:, transaction:)
        transaction = ::Paddle::Transaction.retrieve(id: transaction)
        return unless transaction.status == "completed"
        return if transaction.payments.empty?
        sync(pay_customer: pay_customer, attributes: transaction.payments.first)
      end

      def self.sync(pay_customer:, attributes:, try: 0, retries: 1)
        details = attributes.method_details
        attrs = {
          payment_method_type: details.type.downcase
        }

        case details.type.downcase
        when "card"
          attrs[:brand] = details.card.type
          attrs[:last4] = details.card.last4
          attrs[:exp_month] = details.card.expiry_month
          attrs[:exp_year] = details.card.expiry_year
        end

        payment_method = pay_customer.payment_methods.find_or_initialize_by(processor_id: attributes.payment_method_id)
        payment_method.update!(attrs)
        payment_method
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        if try <= retries
          sleep 0.1
          retry
        else
          raise
        end
      end

      def make_default!
      end

      def detach
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_paddle_billing_payment_method, Pay::PaddleBilling::PaymentMethod
