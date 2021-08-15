module Pay
  class Charge < Pay::ApplicationRecord
    self.inheritance_column = nil

    # Associations
    belongs_to :customer
    belongs_to :subscription, optional: true, class_name: "Pay::Subscription", foreign_key: :pay_subscription_id

    # Scopes
    scope :sorted, -> { order(created_at: :desc) }
    default_scope -> { sorted }

    # Validations
    validates :amount, presence: true
    validates :processor_id, presence: true, uniqueness: {scope: :customer_id}

    # Store the payment method kind (card, paypal, etc)
    store_accessor :data, :paddle_receipt_url
    store_accessor :data, :stripe_account

    # Payment method attributes
    store_accessor :data, :payment_method_type # card, paypal, sepa, etc
    store_accessor :data, :brand # Visa, Mastercard, Discover, PayPal
    store_accessor :data, :last4
    store_accessor :data, :exp_month
    store_accessor :data, :exp_year
    store_accessor :data, :email # PayPal email, etc
    store_accessor :data, :username # Venmo
    store_accessor :data, :bank

    # Helpers for payment processors
    %w[braintree stripe paddle fake_processor].each do |processor_name|
      define_method "#{processor_name}?" do
        customer.processor == processor_name
      end

      scope processor_name, -> { where(processor: processor_name) }
    end

    def self.find_by_processor_and_id(processor, processor_id)
      joins(:customer).find_by(processor_id: processor_id, pay_customers: {processor: processor})
    end

    def self.pay_processor_for(name)
      "Pay::#{name.to_s.classify}::Charge".constantize
    end

    def payment_processor
      @payment_processor ||= self.class.pay_processor_for(customer.processor).new(self)
    end

    def processor_charge
      payment_processor.charge
    end

    def refund!(refund_amount = nil)
      refund_amount ||= amount
      payment_processor.refund!(refund_amount)
    end

    def charged_to
      "#{card_type} (**** **** **** #{card_last4})"
    end
  end
end
