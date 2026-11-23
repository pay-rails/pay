module Pay
  module PaddleBilling
    class Charge < Pay::Charge
      extend Pay::Sync

      store_accessor :data, :paddle_receipt_url

      def self.sync(charge_id, object: nil)
        sync_with_retries do
          transaction = object || ::Paddle::Transaction.retrieve(id: charge_id, extra: "adjustments_totals")

          # Ignore transactions that aren't completed
          return unless transaction.status == "completed"
          return unless (pay_customer = find_pay_customer(transaction.customer_id))

          # Ignore transactions that are payment method changes
          # But update the customer's payment method
          if transaction.origin == "subscription_payment_method_change"
            Pay::PaddleBilling::PaymentMethod.sync(pay_customer: pay_customer, attributes: transaction.payments.first)
            return
          end

          attrs = {
            amount: transaction.details.totals.grand_total,
            created_at: transaction.created_at,
            currency: transaction.currency_code,
            metadata: transaction.details.line_items&.first&.id,
            subscription: pay_customer.subscriptions.find_by(processor_id: transaction.subscription_id)
          }

          # Paddle counts approved refunds only, so pending and rejected ones leave this alone
          if (adjustments_totals = transaction.adjustments_totals)
            attrs[:amount_refunded] = adjustments_totals.breakdown.refund.to_i
          end

          if (details = Array.wrap(transaction.payments).first&.method_details)
            case details.type.downcase
            when "card"
              attrs[:payment_method_type] = "card"
              attrs[:brand] = details.card.type
              attrs[:exp_month] = details.card.expiry_month
              attrs[:exp_year] = details.card.expiry_year
              attrs[:last4] = details.card.last4
            when "paypal"
              attrs[:payment_method_type] = "paypal"
            end

            # Update customer's payment method
            Pay::PaddleBilling::PaymentMethod.sync(pay_customer: pay_customer, attributes: transaction.payments.first)
          end

          # Update or create the charge
          if (pay_charge = find_by(customer: pay_customer, processor_id: transaction.id))
            pay_charge.with_lock { pay_charge.update!(attrs) }
            pay_charge
          else
            create!(attrs.merge(customer: pay_customer, processor_id: transaction.id))
          end
        end
      end

      # Requests a refund from Paddle and returns the Paddle::Adjustment
      #
      # Paddle refunds start out pending approval, so amount_refunded is updated by the
      # adjustment webhooks once Paddle approves it.
      #
      # Only refunding the whole of an unrefunded charge is a full adjustment. Anything else
      # is a partial adjustment against the transaction's single line item.
      #
      #   refund!
      #   refund!(5_00, reason: "Customer request")
      def refund!(amount_to_refund = nil, reason: I18n.t("pay.refund"))
        remaining = amount - amount_refunded.to_i
        amount_to_refund ||= remaining
        raise Pay::PaddleBilling::Error, "#{processor_id} has nothing left to refund" unless remaining.positive?
        unless amount_to_refund.positive? && amount_to_refund <= remaining
          raise Pay::PaddleBilling::Error, "#{processor_id} can refund between 1 and #{remaining}, not #{amount_to_refund}"
        end

        params = {transaction_id: processor_id, action: "refund", reason: reason, type: "full"}

        unless amount_to_refund == amount
          line_items = ::Paddle::Transaction.retrieve(id: processor_id).details.line_items
          unless line_items.size == 1
            raise Pay::PaddleBilling::Error, "Paddle Billing partial refunds need a transaction with one line item, but #{processor_id} has #{line_items.size}"
          end

          params[:type] = "partial"
          params[:items] = [{item_id: line_items.first.id, type: "partial", amount: amount_to_refund.to_s}]
        end

        ::Paddle::Adjustment.create(**params)
      rescue ::Paddle::ErrorGenerator => e
        raise Pay::PaddleBilling::Error, e
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_paddle_billing_charge, Pay::PaddleBilling::Charge
