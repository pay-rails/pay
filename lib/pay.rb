require 'braintree'
require 'stripe'
require 'stripe_event'
require 'pay/engine'
require 'pay/billable'

# Subscription backends
require_relative 'pay/subscription/stripe'
require_relative 'pay/subscription/braintree'

# Webhook processors
require_relative 'pay/stripe/charge_succeeded'
require_relative 'pay/stripe/charge_refunded'
require_relative 'pay/stripe/subscription_canceled'
require_relative 'pay/stripe/subscription_renewing'

module Pay
  # Define who owns the subscription
  mattr_accessor :billable_class
  mattr_accessor :billable_table
  mattr_accessor :braintree_gateway

  @@billable_class = 'User'
  @@billable_table = @@billable_class.tableize

  mattr_accessor :business_name
  mattr_accessor :business_address

  mattr_accessor :send_emails
  @@send_emails = true

  def self.setup
    yield self
  end
end
