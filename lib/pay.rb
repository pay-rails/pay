require "pay/version"
require "pay/engine"
require "pay/errors"
require "pay/adapter"

require "action_mailer"
require "active_support"

module Pay
  autoload :Attributes, "pay/attributes"
  autoload :Env, "pay/env"
  autoload :NanoId, "pay/nano_id"
  autoload :Payment, "pay/payment"
  autoload :Receipts, "pay/receipts"
  autoload :Currency, "pay/currency"

  # Payment processors
  autoload :Braintree, "pay/braintree"
  autoload :FakeProcessor, "pay/fake_processor"
  autoload :PaddleBilling, "pay/paddle_billing"
  autoload :PaddleClassic, "pay/paddle_classic"
  autoload :LemonSqueezy, "pay/lemon_squeezy"
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
  mattr_accessor :business_logo
  mattr_accessor :support_email

  def self.support_email=(value)
    @@support_email = value.is_a?(::Mail::Address) ? value : ::Mail::Address.new(value)
  end

  mattr_accessor :automount_routes
  @@automount_routes = true

  mattr_accessor :default_product_name
  @@default_product_name = "default"

  mattr_accessor :default_plan_name
  @@default_plan_name = "default"

  mattr_accessor :routes_path
  @@routes_path = "/pay"

  mattr_accessor :enabled_processors
  @@enabled_processors = [:stripe, :braintree, :paddle_billing, :paddle_classic, :lemon_squeezy]

  mattr_accessor :send_emails
  @@send_emails = true

  mattr_accessor :emails
  @@emails = ActiveSupport::OrderedOptions.new
  @@emails.payment_action_required = true
  @@emails.payment_failed = true
  @@emails.receipt = true
  @@emails.refund = true
  # This only applies to Stripe, therefor we supply the second argument of price
  @@emails.subscription_renewing = ->(pay_subscription, price) {
    (price&.type == "recurring") && (price.recurring&.interval == "year")
  }
  @@emails.subscription_trial_will_end = true
  @@emails.subscription_trial_ended = true

  @@mailer = "Pay::UserMailer"

  def self.mailer=(value)
    @@mailer = value
    @@mailer_ref = nil
  end

  def self.mailer
    @@mailer_ref ||= @@mailer&.constantize
  end

  mattr_accessor :parent_mailer
  @@parent_mailer = "Pay::ApplicationMailer"

  # Should return a hash of arguments for the `mail` call in UserMailer
  mattr_accessor :mail_arguments
  @@mail_arguments = -> {
    {
      to: instance_exec(&Pay.mail_to),
      subject: default_i18n_subject(application: Pay.application_name)
    }
  }

  # Should return String or Array of email recipients
  mattr_accessor :mail_to
  @@mail_to = -> {
    if ::ActionMailer::Base.respond_to?(:email_address_with_name)
      ::ActionMailer::Base.email_address_with_name(params[:pay_customer].email, params[:pay_customer].customer_name)
    else
      ::Mail::Address.new.tap do |builder|
        builder.address = params[:pay_customer].email
        builder.display_name = params[:pay_customer].customer_name.presence
      end.to_s
    end
  }

  def self.setup
    yield self
  end

  def self.send_email?(email_option, *remaining_args)
    if resolve_option(send_emails, *remaining_args)
      email_config_option_enabled = emails.send(email_option)
      resolve_option(email_config_option_enabled, *remaining_args)
    else
      false
    end
  end

  def self.resolve_option(option, *remaining_args)
    if option.respond_to?(:call)
      option.call(*remaining_args)
    else
      option
    end
  end
end
