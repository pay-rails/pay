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
end
