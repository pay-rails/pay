require 'stripe'
require 'pay/engine'
require 'pay/billable'

module Pay
  # Define who owns the subscription
  mattr_accessor :billable_class
  @@billable_class = 'User'

  def self.setup
    yield self
  end

  def self.billable_table
    @@billable_class.tableize
  end

  def self.billable_key
    @@billable_class.foreign_key
  end
end
