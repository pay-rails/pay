module Pay
  class PaymentMethod < Pay::ApplicationRecord
    self.inheritance_column = nil

    belongs_to :customer

    store_accessor :data, :stripe_account
    store_accessor :data, :brand # Visa, Mastercard, Discover, PayPal
    store_accessor :data, :last4
    store_accessor :data, :exp_month
    store_accessor :data, :exp_year
    store_accessor :data, :email # PayPal email, etc
    store_accessor :data, :username
    store_accessor :data, :bank

    # Aliases to share PaymentMethodAttributes
    alias_attribute :payment_method_type, :type

    validates :processor_id, presence: true, uniqueness: {scope: :customer_id, case_sensitive: true}

    def self.find_by_processor_and_id(processor, processor_id)
      joins(:customer).find_by(processor_id: processor_id, pay_customers: {processor: processor})
    end

    def self.pay_processor_for(name)
      "Pay::#{name.to_s.classify}::PaymentMethod".constantize
    end

    def payment_processor
      @payment_processor ||= self.class.pay_processor_for(customer.processor).new(self)
    end

    def make_default!
      return if default?

      payment_processor.make_default!

      customer.payment_methods.update_all(default: false)
      update!(default: true)
    end
  end
end
