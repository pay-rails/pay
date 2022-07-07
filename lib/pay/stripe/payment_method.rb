module Pay
  module Stripe
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method

      def initialize(pay_payment_method)
        @pay_payment_method = pay_payment_method
      end

      def self.sync(id, object: nil, stripe_account: nil, try: 0, retries: 1)
        object ||= ::Stripe::PaymentMethod.retrieve(id, {stripe_account: stripe_account}.compact)

        pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)
        return unless pay_customer

        # Avoid repeated API calls.
        stripe_customer = pay_customer.customer

        default_payment_method_id = stripe_customer.invoice_settings.default_payment_method

        default_source_id = stripe_customer.default_source

        default = [default_payment_method_id, default_source_id].include?(id)

        attributes = extract_attributes(object).merge(default: default, stripe_account: stripe_account)

        pay_customer.payment_methods.update_all(default: false) if default
        pay_payment_method = pay_customer.payment_methods.where(processor_id: object.id).first_or_initialize
        pay_payment_method.update!(attributes)
        pay_payment_method
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
