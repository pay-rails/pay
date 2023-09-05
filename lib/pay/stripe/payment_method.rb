module Pay
  module Stripe
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method

      def initialize(pay_payment_method)
        @pay_payment_method = pay_payment_method
      end

      # Syncs a PaymentIntent's payment method to the database
      def self.sync_payment_intent(id, stripe_account: nil)
        payment_intent = ::Stripe::PaymentIntent.retrieve({id: id, expand: ["payment_method"]}, {stripe_account: stripe_account}.compact)
        payment_method = payment_intent.payment_method
        return unless payment_method
        Pay::Stripe::PaymentMethod.sync(payment_method.id, object: payment_method)
      end

      # Syncs a SetupIntent's payment method to the database
      def self.sync_setup_intent(id, stripe_account: nil)
        setup_intent = ::Stripe::SetupIntent.retrieve({id: id, expand: ["payment_method"]}, {stripe_account: stripe_account}.compact)
        payment_method = setup_intent.payment_method
        return unless payment_method
        Pay::Stripe::PaymentMethod.sync(payment_method.id, object: payment_method)
      end

      # Syncs PaymentMethod objects from Stripe
      def self.sync(id, object: nil, stripe_account: nil, try: 0, retries: 1)
        object ||= ::Stripe::PaymentMethod.retrieve(id, {stripe_account: stripe_account}.compact)
        if object.customer.blank?
          Rails.logger.debug "Stripe PaymentMethod #{object.id} does not have a customer"
          return
        end

        pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)
        if pay_customer.blank?
          Rails.logger.debug "Pay::Customer #{object.customer} is not in the database while syncing Stripe PaymentMethod #{object.id}"
          return
        end

        default_payment_method_id = pay_customer.customer.invoice_settings.default_payment_method
        default = (id == default_payment_method_id)

        attributes = extract_attributes(object).merge(default: default, stripe_account: stripe_account)

        pay_customer.payment_methods.update_all(default: false) if default
        pay_payment_method = pay_customer.payment_methods.where(processor_id: object.id).first_or_initialize
        pay_payment_method.update!(attributes)
        pay_payment_method
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        if try <= retries
          sleep 0.1
          retry
        else
          raise
        end
      end

      # Extracts payment method details from a Stripe::PaymentMethod object
      def self.extract_attributes(payment_method)
        details = payment_method.send(payment_method.type)

        {
          payment_method_type: payment_method.type,
          brand: details.try(:brand)&.capitalize,
          last4: details.try(:last4).to_s,
          exp_month: details.try(:exp_month).to_s,
          exp_year: details.try(:exp_year).to_s,
          bank: details.try(:bank_name) || details.try(:bank) # eps, fpx, ideal, p24, acss_debit, etc
        }
      end

      # Sets payment method as default
      def make_default!
        ::Stripe::Customer.update(customer.processor_id, {invoice_settings: {default_payment_method: processor_id}}, stripe_options)
      end

      # Remove payment method
      def detach
        ::Stripe::PaymentMethod.detach(processor_id, stripe_options)
      end

      private

      # Options for Stripe requests
      def stripe_options
        {stripe_account: customer.stripe_account}.compact
      end
    end
  end
end
