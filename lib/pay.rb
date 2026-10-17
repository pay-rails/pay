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
  autoload :Sync, "pay/sync"
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

  # Configuration is kept in instance variables on this module rather than in class variables (mattr_accessor),
  # because Ruby forbids reading class variables from a non-main Ractor. Pay.make_shareable! deep-freezes these
  # values before Rails shares the application with Ractors.
  class << self
    attr_accessor :model_parent_class

    # Business details for receipts
    attr_accessor :application_name, :business_address, :business_name, :business_logo
    attr_reader :support_email

    attr_accessor :automount_routes, :routes_path
    attr_accessor :default_product_name, :default_plan_name
    attr_accessor :enabled_processors
    attr_accessor :send_emails, :emails
    attr_writer :mailer, :braintree_gateway
    attr_accessor :parent_mailer, :mail_arguments, :mail_to
  end

  self.model_parent_class = "ApplicationRecord"

  def self.support_email=(value)
    @support_email = value.is_a?(::Mail::Address) ? value : ::Mail::Address.new(value)
  end

  self.automount_routes = true
  self.default_product_name = "default"
  self.default_plan_name = "default"
  self.routes_path = "/pay"
  self.enabled_processors = [:stripe, :braintree, :paddle_billing, :paddle_classic, :lemon_squeezy]
  self.send_emails = true

  self.emails = ActiveSupport::OrderedOptions.new
  emails.payment_action_required = true
  emails.payment_failed = true
  emails.receipt = true
  emails.refund = true
  # This only applies to Stripe, therefor we supply the second argument of price
  emails.subscription_renewing = ->(pay_subscription, price) {
    (price&.type == "recurring") && (price.recurring&.interval == "year")
  }
  emails.subscription_trial_will_end = true
  emails.subscription_trial_ended = true

  self.mailer = "Pay::UserMailer"

  # Resolved on every call rather than memoized, so code reloading in development returns the current class
  def self.mailer
    @mailer.constantize
  end

  # The gateway assigned by Pay::Braintree.setup or by the app. A gateway holds a logger, which can't be deep-frozen,
  # so instead of sharing this one each non-main Ractor builds its own from the same credentials.
  def self.braintree_gateway
    if non_main_ractor?
      ::Ractor.current[:pay_braintree_gateway] ||= Pay::Braintree.new_gateway
    else
      @braintree_gateway
    end
  end

  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new("13.0", "Pay")
  end

  self.parent_mailer = "Pay::ApplicationMailer"

  # Should return a hash of arguments for the `mail` call in UserMailer
  self.mail_arguments = -> {
    {
      to: instance_exec(&Pay.mail_to),
      subject: default_i18n_subject(application: Pay.application_name)
    }
  }

  # Should return String or Array of email recipients
  self.mail_to = -> {
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

  # Deep-freezes an object so every Ractor can read it. Without Ractor support (JRuby) it is only frozen.
  def self.make_shareable(object)
    defined?(::Ractor) ? ::Ractor.make_shareable(object) : object.freeze
  end

  def self.non_main_ractor?
    defined?(::Ractor) && ::Ractor.current != ::Ractor.main
  end

  # Prepares Pay for Rails' experimental Rails.application.ractorize!, which Rails runs from its before_ractorize
  # load hook (see Pay::Engine): resolves the processor credentials, rebinds callable options so they can be shared,
  # warms lazily built values and deep-freezes all of it. Configuration can't change afterwards.
  def self.make_shareable!
    return unless defined?(::Ractor)

    self.send_emails = shareable_callable(send_emails)
    self.mail_to = shareable_callable(mail_to)
    self.mail_arguments = shareable_callable(mail_arguments)
    emails.transform_values! { |option| shareable_callable(option) }

    # Mail::Address memoizes its display name on first use
    support_email&.display_name

    [Stripe, Braintree, PaddleBilling, PaddleClassic, LemonSqueezy].each(&:freeze_credentials!)

    customer_models = ActiveRecord::Base.descendants.select { |model| model.include?(Pay::Attributes::CustomerExtension) }
    customer_models.each do |model|
      model.pay_stripe_customer_attributes = shareable_callable(model.pay_stripe_customer_attributes)
      model.pay_braintree_customer_attributes = shareable_callable(model.pay_braintree_customer_attributes)
      make_shareable [model.pay_default_payment_processor, model.pay_stripe_customer_attributes, model.pay_braintree_customer_attributes]
    end

    make_shareable [
      model_parent_class, application_name, business_address, business_name, business_logo, support_email,
      automount_routes, routes_path, default_product_name, default_plan_name, enabled_processors,
      send_emails, emails, @mailer, parent_mailer, mail_arguments, mail_to,
      Stripe.model_names, Currency.all, Webhooks.delegator, deprecator
    ]
  end

  # A lambda written in an initializer has the initializer's `main` object as self, which can't be shared, so it is
  # re-created with nil as self. Lambdas Pay runs with instance_exec get their self replaced anyway. Options that
  # aren't callable are returned as they are.
  def self.shareable_callable(option)
    return option unless option.is_a?(Proc)

    option.lambda? ? ::Ractor.shareable_lambda(self: nil, &option) : ::Ractor.shareable_proc(self: nil, &option)
  end
  private_class_method :shareable_callable

  SYNC_HANDLERS = make_shareable({
    lemon_squeezy_order_id: ->(param) { Pay::LemonSqueezy.sync_order(param) },
    paddle_billing_transaction_id: ->(param) { Pay::PaddleBilling.sync_transaction(param) },
    stripe_checkout_session_id: ->(param) { Pay::Stripe.sync_checkout_session(param) },
    transaction_id: ->(param) { Pay::PaddleBilling.sync_transaction(param) },
    session_id: ->(param) { Pay::Stripe.sync_checkout_session(param) }
  })

  def self.sync(params)
    SYNC_HANDLERS.each do |param_name, handler|
      if (param = params[param_name])
        return handler.call(param)
      end
    end
    nil
  end
end
