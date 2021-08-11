class Pay::PaymentMethod < Pay::ApplicationRecord
  self.inheritance_column = nil

  belongs_to :customer

  store_accessor :data, :type # card, paypal, ideal, sepa_debit, etc
  store_accessor :data, :brand # Visa, Mastercard, Discover, PayPal
  store_accessor :data, :last4
  store_accessor :data, :exp_month
  store_accessor :data, :exp_year
  store_accessor :data, :email # PayPal email, etc
  store_accessor :data, :username
  store_accessor :data, :bank

  # Aliases to share PaymentMethodAttributes
  alias_attribute :payment_method_type, :type

  def self.find_by_processor_and_id(processor, processor_id)
    joins(:customer).find_by(processor_id: processor_id, pay_customers: {processor: processor})
  end
end
