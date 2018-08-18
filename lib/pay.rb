require 'stripe'
require 'pay/engine'
require 'pay/billable'
require 'pay/stripe/charge_succeeded'
require 'pay/stripe/charge_refunded'

module Pay
  # Define who owns the subscription
  mattr_accessor :billable_class
  mattr_accessor :billable_table
  @@billable_class = 'User'
  @@billable_table = @@billable_class.tableize

  def self.setup
    yield self
  end

  def braintree_gateway(merchant_id:, public_key:, private_key:)
    @braintree_gateway ||= Braintree::Gateway.new(
      environment: :sandbox,
      merchant_id: merchant_id,
      public_key:  public_key,
      private_key: private_key
    )
  end
end
