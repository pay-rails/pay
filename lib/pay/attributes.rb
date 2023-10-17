module Pay
  # Adds Pay methods to ActiveRecord models

  module Attributes
    extend ActiveSupport::Concern

    module CustomerExtension
      extend ActiveSupport::Concern

      included do
        cattr_accessor :pay_default_payment_processor
        cattr_accessor :pay_stripe_customer_attributes
        cattr_accessor :pay_braintree_customer_attributes

        has_many :pay_customers, class_name: "Pay::Customer", as: :owner, inverse_of: :owner
        has_many :charges, through: :pay_customers, class_name: "Pay::Charge"
        has_many :subscriptions, through: :pay_customers, class_name: "Pay::Subscription"
        has_one :payment_processor, -> { where(default: true, deleted_at: nil) }, class_name: "Pay::Customer", as: :owner, inverse_of: :owner

        after_commit :cancel_active_pay_subscriptions!, on: [:destroy]

        Pay::Stripe.model_names << name if Pay::Stripe.enabled?
      end

      # Changes a user's payment processor
      #
      # This has several effects:
      # - Finds or creates a Pay::Customer for the process and marks it as default
      # - Removes the default flag from all other Pay::Customers
      # - Removes the default flag from all Pay::PaymentMethods
      def set_payment_processor(processor_name, allow_fake: false, **attributes)
        raise Pay::Error, "Processor `#{processor_name}` is not allowed" if processor_name.to_s == "fake_processor" && !allow_fake

        ActiveRecord::Base.transaction do
          pay_customers.update_all(default: false)
          pay_customer = pay_customers.active.where(processor: processor_name).first_or_initialize
          pay_customer.update!(attributes.merge(default: true))
        end

        # Return new payment processor
        reload_payment_processor
      end

      def add_payment_processor(processor_name, allow_fake: false, **attributes)
        raise Pay::Error, "Processor `#{processor_name}` is not allowed" if processor_name.to_s == "fake_processor" && !allow_fake

        pay_customer = pay_customers.active.where(processor: processor_name).first_or_initialize
        pay_customer.update!(attributes)
        pay_customer
      end

      def payment_processor
        current_processor = super

        if current_processor.blank? && self.class.pay_default_payment_processor.present?
          set_payment_processor(self.class.pay_default_payment_processor, allow_fake: true)
        else
          current_processor
        end
      end

      def cancel_active_pay_subscriptions!
        subscriptions.active.each(&:cancel_now!)
      end
    end

    module MerchantExtension
      extend ActiveSupport::Concern

      included do
        has_many :pay_merchants, class_name: "Pay::Merchant", as: :owner, inverse_of: :owner
        has_one :merchant_processor, -> { where(default: true) }, class_name: "Pay::Merchant", as: :owner, inverse_of: :owner
      end

      def set_merchant_processor(processor_name, **attributes)
        ActiveRecord::Base.transaction do
          pay_merchants.update_all(default: false)
          pay_merchant = pay_merchants.where(processor: processor_name).first_or_initialize
          pay_merchant.update!(attributes.merge(default: true))
        end

        # Return new payment processor
        reload_merchant_processor
      end
    end

    class_methods do
      def pay_customer(options = {})
        include Billable::SyncCustomer
        include CustomerExtension

        self.pay_default_payment_processor = options[:default_payment_processor]
        self.pay_stripe_customer_attributes = options[:stripe_attributes]
        self.pay_braintree_customer_attributes = options[:braintree_attributes]
      end

      def pay_merchant(options = {})
        include MerchantExtension
      end
    end
  end
end
