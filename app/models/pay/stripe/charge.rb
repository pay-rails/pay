module Pay
  module Stripe
    class Charge < Pay::Charge
      extend Pay::Stripe::Sync

      EXPAND = ["balance_transaction", "payment_intent", "refunds.data.balance_transaction"]

      delegate :amount_captured, :payment_intent, to: :stripe_object, allow_nil: true

      store_accessor :data, :stripe_invoice
      store_accessor :data, :stripe_receipt_url

      def self.sync_payment_intent(id, stripe_account: nil)
        payment_intent = ::Stripe::PaymentIntent.retrieve({id: id}, {stripe_account: stripe_account}.compact)
        sync(payment_intent.latest_charge, stripe_account: stripe_account)
      end

      def self.sync(charge_id, object: nil, stripe_account: nil, retries: 1)
        sync_with_retries(retries: retries) do
          charge = object || ::Stripe::Charge.retrieve({id: charge_id, expand: EXPAND}, {stripe_account: stripe_account}.compact)
          return unless (pay_customer = find_pay_customer(charge))
          stripe_account ||= pay_customer.stripe_account

          payment_method = charge.payment_method_details.try(charge.payment_method_details.type)
          attrs = {
            object: charge.to_hash,
            amount: charge.amount,
            amount_refunded: charge.amount_refunded,
            application_fee_amount: charge.application_fee_amount,
            bank: payment_method.try(:bank_name) || payment_method.try(:bank), # eps, fpx, ideal, p24, acss_debit, etc
            brand: payment_method.try(:brand)&.capitalize,
            created_at: Time.at(charge.created),
            currency: charge.currency,
            exp_month: payment_method.try(:exp_month).to_s,
            exp_year: payment_method.try(:exp_year).to_s,
            last4: payment_method.try(:last4).to_s,
            metadata: charge.metadata,
            payment_method_type: charge.payment_method_details.type,
            stripe_account: stripe_account,
            stripe_receipt_url: charge.receipt_url
          }

          # Associate charge with subscription if we can
          if charge.payment_intent.present?
            invoice_payments = ::Stripe::InvoicePayment.list({payment: {type: :payment_intent, payment_intent: charge.payment_intent}, status: :paid}, {stripe_account: stripe_account}.compact)
            if invoice_payments.any?
              invoice = ::Stripe::Invoice.retrieve({id: invoice_payments.first.invoice, expand: ["total_discount_amounts.discount.source.coupon"]}, {stripe_account: stripe_account}.compact)
              attrs[:stripe_invoice] = invoice.to_hash
              attrs[:subtotal] = invoice.subtotal
              attrs[:tax] = invoice.total - invoice.total_excluding_tax.to_i
              if (subscription = invoice.parent.try(:subscription_details).try(:subscription))
                attrs[:subscription] = pay_customer.subscriptions.find_by(processor_id: subscription)
              end
            end
          end

          # Update or create the charge
          if (pay_charge = find_by(customer: pay_customer, processor_id: charge.id))
            pay_charge.with_lock { pay_charge.update!(attrs) }
            pay_charge
          else
            create!(attrs.merge(customer: pay_customer, processor_id: charge.id))
          end
        end
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
      def refund!(amount_to_refund = nil, **options)
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
        payment_intent_id = payment_intent.is_a?(::Stripe::PaymentIntent) ? payment_intent.id : payment_intent
        ::Stripe::PaymentIntent.capture(payment_intent_id, options, stripe_options)
        self.class.sync(processor_id, stripe_account: stripe_account)
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
        sync! if object.nil?
        ::Stripe::Charge.construct_from(object)
      end

      def sync!(**options)
        super(**options.with_defaults(stripe_account: stripe_account))
      end

      private

      # Options for Stripe requests
      def stripe_options
        {stripe_account: stripe_account}.compact
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_stripe_charge, Pay::Stripe::Charge
