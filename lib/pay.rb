require 'stripe'
require 'pay/engine'
require 'pay/billable'

module Pay
  # Define who owns the subscription
  mattr_accessor :billable_class
  mattr_accessor :billable_table
  @@billable_class = 'User'
  @@billable_table = @@billable_class.tableize

  def self.setup
    yield self
  end
end
