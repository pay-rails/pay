module Pay
  class Charge < Pay::ApplicationRecord
    # Associations
    belongs_to :customer
    belongs_to :subscription, optional: true

    # Scopes
    scope :sorted, -> { order(created_at: :desc) }
    scope :with_active_customer, -> { joins(:customer).merge(Customer.active) }
    scope :with_deleted_customer, -> { joins(:customer).merge(Customer.deleted) }

    # Validations
    validates :amount, presence: true
    validates :processor_id, presence: true, uniqueness: {scope: :customer_id, case_sensitive: true}

    delegate :owner, to: :customer

    # Payment method attributes
    store_accessor :data, :payment_method_type # card, paypal, sepa, etc
    store_accessor :data, :brand # Visa, Mastercard, Discover, PayPal
    store_accessor :data, :last4
    store_accessor :data, :exp_month
    store_accessor :data, :exp_year
    store_accessor :data, :email # PayPal email, etc
    store_accessor :data, :username # Venmo
    store_accessor :data, :bank

    store_accessor :data, :subtotal
    store_accessor :data, :tax

    # Helpers for payment processors
    %w[braintree stripe paddle_billing paddle_classic lemon_squeezy fake_processor].each do |processor_name|
      define_method :"#{processor_name}?" do
        customer.processor == processor_name
      end

      scope processor_name, -> { joins(:customer).where(pay_customers: {processor: processor_name}) }
    end

    def self.find_by_processor_and_id(processor, processor_id)
      joins(:customer).find_by(processor_id: processor_id, pay_customers: {processor: processor})
    end

    def sync!(**options)
      self.class.sync(processor_id, **options)
      reload
    end

    def refunded?
      amount_refunded.to_i > 0
    end

    def full_refund?
      refunded? && amount == amount_refunded
    end

    def partial_refund?
      refunded? && !full_refund?
    end

    def amount_with_currency
      Pay::Currency.format(amount, currency: currency)
    end

    def amount_refunded_with_currency
      Pay::Currency.format(amount_refunded, currency: currency)
    end

    def charged_to
      case payment_method_type
      when "card"
        "#{brand.titleize} (**** **** **** #{last4})"
      when "paypal"
        # Sometimes brand and email are missing (Stripe)
        brand ||= "PayPal"
        if email.present?
          brand + " (#{email})"
        else
          brand
        end

      # Braintree
      when "venmo"
        "#{brand.titleize} #{username}"
      when "us_bank_account"
        "#{bank} #{last4}"

      # Stripe
      when "acss_debit"
        "#{bank} #{last4}"
      when "eps", "fpx", "ideal", "p24"
        bank

      when "au_becs_debit"
        "BECS Debit #{last4}"

      when "bacs_debit"
        "Bacs Debit #{last4}"

      when "sepa_debit"
        "SEPA Debit #{last4}"

      else
        payment_method_type&.titleize
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_charge, Pay::Charge
