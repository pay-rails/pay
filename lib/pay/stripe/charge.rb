module Pay
  module Stripe
    class Charge
      attr_reader :pay_charge

      delegate :amount,
        :amount_captured,
        :invoice_id,
        :line_items,
        :payment_intent_id,
        :processor_id,
        :stripe_account,
        to: :pay_charge

      def self.sync(charge_id, object: nil, stripe_account: nil, try: 0, retries: 1)
        # Skip loading the latest charge details from the API if we already have it
        object ||= ::Stripe::Charge.retrieve({id: charge_id, expand: ["invoice.total_discount_amounts.discount", "invoice.total_tax_amounts.tax_rate", "refunds"]}, {stripe_account: stripe_account}.compact)

        # Ignore charges without a Customer
        return if object.customer.blank?

        pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)
        return unless pay_customer

        refunds = []
        object.refunds.auto_paging_each { |refund| refunds << refund }

        payment_method = object.payment_method_details.send(object.payment_method_details.type)
        attrs = {
          amount: object.amount,
          amount_captured: object.amount_captured,
          amount_refunded: object.amount_refunded,
          application_fee_amount: object.application_fee_amount,
          bank: payment_method.try(:bank_name) || payment_method.try(:bank), # eps, fpx, ideal, p24, acss_debit, etc
          brand: payment_method.try(:brand)&.capitalize,
          created_at: Time.at(object.created),
          currency: object.currency,
          discounts: [],
          exp_month: payment_method.try(:exp_month).to_s,
          exp_year: payment_method.try(:exp_year).to_s,
          last4: payment_method.try(:last4).to_s,
          line_items: [],
          metadata: object.metadata,
          payment_intent_id: object.payment_intent,
          payment_method_type: object.payment_method_details.type,
          stripe_account: pay_customer.stripe_account,
          stripe_receipt_url: object.receipt_url,
          total_tax_amounts: [],
          refunds: refunds.sort_by! { |r| r["created"] }
        }

        # Associate charge with subscription if we can
        if object.invoice
          invoice = (object.invoice.is_a?(::Stripe::Invoice) ? object.invoice : ::Stripe::Invoice.retrieve({id: object.invoice, expand: ["total_discount_amounts.discount", "total_tax_amounts.tax_rate"]}, {stripe_account: stripe_account}.compact))
          attrs[:invoice_id] = invoice.id
          attrs[:subscription] = pay_customer.subscriptions.find_by(processor_id: invoice.subscription)

          attrs[:period_start] = Time.at(invoice.period_start)
          attrs[:period_end] = Time.at(invoice.period_end)
          attrs[:subtotal] = invoice.subtotal
          attrs[:tax] = invoice.tax
          attrs[:discounts] = invoice.discounts
          attrs[:total_tax_amounts] = invoice.total_tax_amounts.map(&:to_hash)
          attrs[:total_discount_amounts] = invoice.total_discount_amounts.map(&:to_hash)

          invoice.lines.auto_paging_each do |line_item|
            # Currency is tied to the charge, so storing it would be duplication
            attrs[:line_items] << {
              id: line_item.id,
              description: line_item.description,
              price_id: line_item.price&.id,
              quantity: line_item.quantity,
              unit_amount: line_item.price&.unit_amount,
              amount: line_item.amount,
              discounts: line_item.discounts,
              tax_amounts: line_item.tax_amounts,
              proration: line_item.proration,
              period_start: Time.at(line_item.period.start),
              period_end: Time.at(line_item.period.end)
            }
          end
        # Charges without invoices
        else
          attrs[:period_start] = Time.at(object.created)
          attrs[:period_end] = Time.at(object.created)
        end

        # Update or create the charge
        if (pay_charge = pay_customer.charges.find_by(processor_id: object.id))
          pay_charge.with_lock do
            pay_charge.update!(attrs)
          end
          pay_charge
        else
          pay_customer.charges.create!(attrs.merge(processor_id: object.id))
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
        ::Stripe::Charge.retrieve({id: processor_id, expand: ["customer", "invoice.subscription"]}, stripe_options)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Issues a CreditNote if there's an invoice, otherwise uses a Refund
      # This allows Tax to be handled properly
      #
      # https://stripe.com/docs/api/credit_notes/create
      # https://stripe.com/docs/api/refunds/create
      #
      # refund!
      # refund!(5_00)
      # refund!(5_00, refund_application_fee: true)
      def refund!(amount_to_refund, **options)
        if invoice_id.present?
          description = options.delete(:description) || I18n.t("pay.refund")
          lines = [{type: :custom_line_item, description: description, quantity: 1, unit_amount: amount_to_refund}]
          credit_note!(**options.merge(refund_amount: amount_to_refund, lines: lines))
        else
          ::Stripe::Refund.create(options.merge(charge: processor_id, amount: amount_to_refund), stripe_options)
        end
        pay_charge.update!(amount_refunded: pay_charge.amount_refunded + amount_to_refund)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Adds a credit note to a Stripe Invoice
      def credit_note!(**options)
        raise Pay::Stripe::Error, "no Stripe invoice_id on Pay::Charge" if invoice_id.blank?
        ::Stripe::CreditNote.create({invoice: invoice_id}.merge(options), stripe_options)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def credit_notes(**options)
        raise Pay::Stripe::Error, "no Stripe invoice_id on Pay::Charge" if invoice_id.blank?
        ::Stripe::CreditNote.list({invoice: invoice_id}.merge(options), stripe_options)
      end

      # https://stripe.com/docs/payments/capture-later
      #
      # capture
      # capture(amount_to_capture: 15_00)
      def capture(**options)
        raise Pay::Stripe::Error, "no payment_intent_id on charge" unless payment_intent_id.present?
        ::Stripe::PaymentIntent.capture(payment_intent_id, options, stripe_options)
        self.class.sync(processor_id)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      private

      # Options for Stripe requests
      def stripe_options
        {stripe_account: stripe_account}.compact
      end
    end
  end
end
