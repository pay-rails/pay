require 'pay/engine'
require 'pay/billable'
require 'pay/receipts'

module Pay
  # Define who owns the subscription
  mattr_accessor :billable_class
  mattr_accessor :billable_table
  mattr_accessor :braintree_gateway

  @@billable_class = 'User'
  @@billable_table = @@billable_class.tableize

  mattr_accessor :chargeable_class
  mattr_accessor :chargeable_table
  @@chargeable_class = 'Pay::Charge'
  @@chargeable_table = 'pay_charges'

  mattr_accessor :subscription_class
  mattr_accessor :subscription_table
  @@subscription_class = 'Pay::Subscription'
  @@subscription_table = 'pay_subscriptions'

  # Business details for receipts
  mattr_accessor :application_name
  mattr_accessor :business_address
  mattr_accessor :business_name
  mattr_accessor :support_email

  # Email configuration
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

  def self.user_model
    @@user_model ||= billable_class.constantize
  end

  def self.charge_model
    @@charge_model ||= chargeable_class.constantize
  end

  def self.subscription_model
    @@subscription_model ||= subscription_class.constantize
  end

  def self.receipts_supported?
    charge_model.respond_to?(:receipt) &&
      application_name.present? &&
      business_name &&
      business_address &&
      support_email
  end

  class Error < StandardError
  end
end
