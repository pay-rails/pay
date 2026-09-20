module Pay
  module Stripe
    class PaymentMethod < Pay::PaymentMethod
      extend Pay::Sync

      # Syncs a PaymentIntent's payment method to the database
      def self.sync_payment_intent(id, stripe_account: nil)
        payment_intent = ::Stripe::PaymentIntent.retrieve({id: id, expand: ["payment_method"]}, {stripe_account: stripe_account}.compact)
        payment_method = payment_intent.payment_method
        return unless payment_method
        Pay::Stripe::PaymentMethod.sync(payment_method.id, object: payment_method, stripe_account: stripe_account)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Syncs a SetupIntent's payment method to the database
      def self.sync_setup_intent(id, stripe_account: nil)
        setup_intent = ::Stripe::SetupIntent.retrieve({id: id, expand: ["payment_method"]}, {stripe_account: stripe_account}.compact)
        payment_method = setup_intent.payment_method
        return unless payment_method
        Pay::Stripe::PaymentMethod.sync(payment_method.id, object: payment_method, stripe_account: stripe_account)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Syncs PaymentMethod objects from Stripe
      def self.sync(id, object: nil, stripe_account: nil, retries: 1)
        sync_with_retries(retries: retries) do
          payment_method = object || ::Stripe::PaymentMethod.retrieve(id, {stripe_account: stripe_account}.compact)
          return unless (pay_customer = find_pay_customer(payment_method.customer))
          stripe_account ||= pay_customer.stripe_account

          default_payment_method_id = pay_customer.api_record.invoice_settings&.default_payment_method
          default = (id == default_payment_method_id)

          attributes = extract_attributes(payment_method).merge(default: default, stripe_account: stripe_account)

          where(customer: pay_customer).update_all(default: false) if default
          pay_payment_method = where(customer: pay_customer, processor_id: payment_method.id).first_or_initialize
          pay_payment_method.update!(attributes)
          pay_payment_method
        end
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Extracts payment method details from a Stripe::PaymentMethod object
      def self.extract_attributes(payment_method)
        details = payment_method.try(payment_method.type)

        {
          payment_method_type: payment_method.type,
          email: details.try(:email), # Link
          brand: details.try(:brand)&.capitalize,
          last4: details.try(:last4).to_s,
          exp_month: details.try(:exp_month).to_s,
          exp_year: details.try(:exp_year).to_s,
          bank: details.try(:bank_name) || details.try(:bank) # eps, fpx, ideal, p24, acss_debit, etc
        }
      end

      # Sets payment method as default
      def make_default!
        return if default?

        ::Stripe::Customer.update(customer.processor_id, {invoice_settings: {default_payment_method: processor_id}}, stripe_options)

        customer.payment_methods.update_all(default: false)
        update!(default: true)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Remove payment method
      def detach
        ::Stripe::PaymentMethod.detach(processor_id, {}, stripe_options)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      private

      # Options for Stripe requests
      def stripe_options
        {stripe_account: customer.stripe_account}.compact
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_stripe_payment_method, Pay::Stripe::PaymentMethod
