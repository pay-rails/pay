require 'braintree'
require 'stripe'
require 'stripe_event'
require 'pay/engine'
require 'pay/billable'

# Subscription backends
require_relative 'pay/subscription/stripe'
require_relative 'pay/subscription/braintree'

# Webhook processors
require_relative 'pay/stripe/charge_refunded'
require_relative 'pay/stripe/charge_succeeded'
require_relative 'pay/stripe/customer_deleted'
require_relative 'pay/stripe/customer_updated'
require_relative 'pay/stripe/source_deleted'
require_relative 'pay/stripe/subscription_deleted'
require_relative 'pay/stripe/subscription_renewing'
require_relative 'pay/stripe/subscription_updated'

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

  mattr_accessor :email_receipt_subject
  @@email_receipt_subject = 'Payment receipt'
  mattr_accessor :email_refund_subject
  @@email_refund_subject = 'Payment refunded'
  mattr_accessor :email_renewing_subject
  @@email_renewing_subject = 'Your upcoming subscription renewal'

  def self.setup
    yield self
  end

  class Error < StandardError;
  end
end
