module Pay
  module Stripe
    class Charge < Pay::Charge
      EXPAND = ["balance_transaction", "payment_intent", "refunds.data.balance_transaction"]

      delegate :amount_captured, :payment_intent, to: :stripe_object

      store_accessor :data, :stripe_invoice
      store_accessor :data, :stripe_receipt_url

      def self.sync_payment_intent(id, stripe_account: nil)
        payment_intent = ::Stripe::PaymentIntent.retrieve({id: id}, {stripe_account: stripe_account}.compact)
        sync(payment_intent.latest_charge, stripe_account: stripe_account)
      end

      def self.sync(charge_id, object: nil, stripe_account: nil, try: 0, retries: 1)
        # Skip loading the latest charge details from the API if we already have it
        object ||= ::Stripe::Charge.retrieve({id: charge_id, expand: EXPAND}, {stripe_account: stripe_account}.compact)
        if object.customer.blank?
          Rails.logger.debug "Stripe Charge #{object.id} does not have a customer"
          return
        end

        pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)
        if pay_customer.blank?
          Rails.logger.debug "Pay::Customer #{object.customer} is not in the database while syncing Stripe Charge #{object.id}"
          return
        end

        payment_method = object.payment_method_details.try(object.payment_method_details.type)
        attrs = {
          object: object.to_hash,
          amount: object.amount,
          amount_refunded: object.amount_refunded,
          application_fee_amount: object.application_fee_amount,
          bank: payment_method.try(:bank_name) || payment_method.try(:bank), # eps, fpx, ideal, p24, acss_debit, etc
          brand: payment_method.try(:brand)&.capitalize,
          created_at: Time.at(object.created),
          currency: object.currency,
          exp_month: payment_method.try(:exp_month).to_s,
          exp_year: payment_method.try(:exp_year).to_s,
          last4: payment_method.try(:last4).to_s,
          metadata: object.metadata,
          payment_method_type: object.payment_method_details.type,
          stripe_account: pay_customer.stripe_account,
          stripe_receipt_url: object.receipt_url
        }

        # Associate charge with subscription if we can
        invoice_payments = ::Stripe::InvoicePayment.list({payment: {type: :payment_intent, payment_intent: object.payment_intent}, status: :paid, expand: ["data.invoice.total_discount_amounts.discount"]}, {stripe_account: stripe_account}.compact)
        if invoice_payments.any? && (invoice = invoice_payments.first.invoice)
          attrs[:stripe_invoice] = invoice.to_hash
          attrs[:subtotal] = invoice.subtotal
          attrs[:tax] = invoice.total - invoice.total_excluding_tax.to_i
          if (subscription = invoice.parent.try(:subscription_details).try(:subscription))
            attrs[:subscription] = pay_customer.subscriptions.find_by(processor_id: subscription)
          end
        end

        # Update or create the charge
        if (pay_charge = find_by(customer: pay_customer, processor_id: object.id))
          pay_charge.with_lock { pay_charge.update!(attrs) }
          pay_charge
        else
          create!(attrs.merge(customer: pay_customer, processor_id: object.id))
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        raise unless try <= retries

        sleep 0.1
        retry
      end

      def api_record
        ::Stripe::Charge.retrieve({id: processor_id, expand: EXPAND}, stripe_options)
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
        amount_to_refund ||= amount

        if stripe_invoice.present?
          description = options.delete(:description) || I18n.t("pay.refund")
          lines = [{type: :custom_line_item, description: description, quantity: 1, unit_amount: amount_to_refund}]
          credit_note!(**options.merge(refund_amount: amount_to_refund, lines: lines))
        else
          ::Stripe::Refund.create(options.merge(charge: processor_id, amount: amount_to_refund), stripe_options)
        end
        update!(amount_refunded: amount_refunded + amount_to_refund)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Adds a credit note to a Stripe Invoice
      def credit_note!(**options)
        raise Pay::Stripe::Error, "no Stripe Invoice on Pay::Charge" if stripe_invoice.blank?

        ::Stripe::CreditNote.create({invoice: stripe_invoice.id}.merge(options), stripe_options)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # https://stripe.com/docs/payments/capture-later
      #
      # capture
      # capture(amount_to_capture: 15_00)
      def capture(**options)
        raise Pay::Stripe::Error, "no payment_intent on charge" unless payment_intent.present?

        ::Stripe::PaymentIntent.capture(payment_intent, options, stripe_options)
        self.class.sync(processor_id)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def captured?
        amount_captured > 0
      end

      def stripe_invoice
        if (value = data.dig("stripe_invoice"))
          ::Stripe::Invoice.construct_from(value)
        end
      end

      def stripe_object
        ::Stripe::Charge.construct_from(object) if object?
      end

      private

      # Options for Stripe requests
      def stripe_options
        {stripe_account: stripe_account}.compact
      end
    end
  end
end
