require 'braintree'
require 'stripe'
require 'pay/engine'
require 'pay/billable'
require 'pay/stripe/charge_succeeded'
require 'pay/stripe/charge_refunded'

module Pay
  # Define who owns the subscription
  mattr_accessor :billable_class
  mattr_accessor :billable_table
  mattr_accessor :braintree_gateway
  @@billable_class = 'User'
  @@billable_table = @@billable_class.tableize

  def self.setup
    yield self
  end
end
