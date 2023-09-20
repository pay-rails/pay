module Pay
  module Lago
    class Charge
      attr_reader :pay_charge

      delegate :processor_id, :owner, to: :pay_charge

      def self.sync(charge_id, object: nil, try: 0, retries: 1)
        object ||= Lago.client.invoices.get(charge_id)

        pay_customer = Pay::Customer.find_by(processor: :lago, processor_id: object.customer.external_id)
        if pay_customer.blank?
          Rails.logger.debug "Pay::Customer #{object.customer} is not in the database while syncing Lago Invoice #{object.lago_id}"
          return
        end

        attrs = {
          processor_id: object.lago_id,
          amount: object.total_amount_cents,
          data: Lago.openstruct_to_h(object)
        }

        if object.subscriptions.present?
          subscription = object.subscriptions.first
          attrs[:subscription] = pay_customer.subscriptions.find_by(processor_id: subscription.try(:lago_id))
        end

        # Update or create the charge
        if (pay_charge = pay_customer.charges.find_by(processor_id: charge_id))
          pay_charge.with_lock do
            pay_charge.update!(attrs)
          end
          pay_charge
        else
          pay_customer.charges.create!(attrs)
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        if try <= retries
          sleep 0.1
          retry
        else
          raise
        end
      end

      def initialize(pay_charge)
        @pay_charge = pay_charge
      end

      def charge
        Lago.client.invoices.get(processor_id)
      rescue ::Lago::Api::HttpError => e
        raise Pay::Lago::Error, e
      end

      def update_charge!(**attributes)
        Lago.client.invoices.update({metadata: []}.merge(attributes), charge.lago_id)
      rescue ::Lago::Api::HttpError => e
        raise Pay::Lago::Error, e
      end

      def refund!(amount_to_refund, **options)
        attributes = {
          refund_amount_cents: amount_to_refund,
          invoice_id: processor_id,
          items: [{fee_id: charge.fees.first.try(:lago_id), amount_cents: amount_to_refund}]
        }
        begin
          Lago.client.credit_notes.create(options.merge(attributes))
        rescue ::Lago::Api::HttpError => e
          if e.error_code == 403
            raise Pay::Lago::Error.new("Creating a credit note requires Lago Premium.")
          else
            raise Pay::Lago::Error, e
          end
        end
        pay_charge.update!(amount_refunded: pay_charge.amount_refunded.to_i + amount_to_refund)
      end
    end
  end
end
