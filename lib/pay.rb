require "pay/version"
require "pay/engine"
require "pay/errors"
require "pay/adapter"

module Pay
  autoload :Attributes, "pay/attributes"
  autoload :Env, "pay/env"
  autoload :NanoId, "pay/nano_id"
  autoload :Payment, "pay/payment"
  autoload :Receipts, "pay/receipts"

  # Payment processors
  autoload :Braintree, "pay/braintree"
  autoload :FakeProcessor, "pay/fake_processor"
  autoload :Paddle, "pay/paddle"
  autoload :Stripe, "pay/stripe"

  autoload :Webhooks, "pay/webhooks"

  module Billable
    autoload :SyncCustomer, "pay/billable/sync_customer"
  end

  mattr_accessor :braintree_gateway

  mattr_accessor :model_parent_class
  @@model_parent_class = "ApplicationRecord"

  # Business details for receipts
  mattr_accessor :application_name
  mattr_accessor :business_address
  mattr_accessor :business_name
  mattr_accessor :support_email

  # Email configuration
  mattr_accessor :send_emails
  @@send_emails = true

  mattr_accessor :automount_routes
  @@automount_routes = true

  mattr_accessor :default_product_name
  @@default_product_name = "default"

  mattr_accessor :default_plan_name
  @@default_plan_name = "default"

  mattr_accessor :routes_path
  @@routes_path = "/pay"
  
  module Emails
    mattr_accessor :receipt
    @@receipt = true

    mattr_accessor :refund
    @@refund = true

    mattr_accessor :subscription_renewing
    @@subscription_renewing = true

    mattr_accessor :payment_action_required
    @@payment_action_required = true
  end

  def self.emails
    Emails
  end

  def self.setup
    yield self
  end

  def self.receipts_supported?
    charge_model.respond_to?(:receipt) &&
      application_name.present? &&
      business_name &&
      business_address &&
      support_email
  end
end
