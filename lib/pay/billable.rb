require "pay/billable/sync_email"

module Pay
  module Billable
    extend ActiveSupport::Concern

    # Keep track of which Billable models we have
    class << self
      attr_reader :includers
    end

    def self.included(base = nil, &block)
      @includers ||= []
      @includers << base if base
      super
    end

    included do |base|
      include Pay::Billable::SyncEmail

      has_many :charges, class_name: Pay.chargeable_class, foreign_key: :owner_id, inverse_of: :owner, as: :owner
      has_many :subscriptions, class_name: Pay.subscription_class, foreign_key: :owner_id, inverse_of: :owner, as: :owner

      attribute :plan, :string
      attribute :quantity, :integer
      attribute :card_token, :string
      attribute :pay_fake_processor_allowed, :boolean, default: false

      # Account(s) for marketplace payments
      store_accessor :pay_data, :stripe_account
      store_accessor :pay_data, :braintree_account

      validate :pay_fake_processor_is_allowed, if: :processor_changed?
    end

    def payment_processor
      @payment_processor ||= payment_processor_for(processor).new(self)
    end

    def payment_processor_for(name)
      raise Error, "No payment processor set. Assign a payment processor with 'object.processor = :stripe' or any supported processor." if name.blank?
      "Pay::#{name.to_s.classify}::Billable".constantize
    end

    # Reset the payment processor when it changes
    def processor=(value)
      super(value)
      self.processor_id = nil if processor_changed?
      @payment_processor = nil
    end

    def processor
      super&.inquiry
    end

    delegate :charge, to: :payment_processor
    delegate :subscribe, to: :payment_processor
    delegate :update_card, to: :payment_processor

    def customer
      raise Pay::Error, I18n.t("errors.email_required") if email.nil?

      customer = payment_processor.customer
      payment_processor.update_card(card_token) if card_token.present?
      customer
    end

    def customer_name
      [try(:first_name), try(:last_name)].compact.join(" ")
    end

    def create_setup_intent
      ActiveSupport::Deprecation.warn("This method will be removed in the next release. Use `@billable.payment_processor.create_setup_intent` instead.")
      payment_processor.create_setup_intent
    end

    def on_trial?(name: Pay.default_product_name, plan: nil)
      return true if default_generic_trial?(name, plan)

      sub = subscription(name: name)
      return sub&.on_trial? if plan.nil?

      sub&.on_trial? && sub.processor_plan == plan
    end

    def on_generic_trial?
      trial_ends_at? && trial_ends_at > Time.zone.now
    end

    def processor_subscription(subscription_id, options = {})
      payment_processor.processor_subscription(subscription_id, options)
    end

    def subscribed?(name: Pay.default_product_name, processor_plan: nil)
      subscription = subscription(name: name)

      return false if subscription.nil?
      return subscription.active? if processor_plan.nil?

      subscription.active? && subscription.processor_plan == processor_plan
    end

    def on_trial_or_subscribed?(name: Pay.default_product_name, processor_plan: nil)
      on_trial?(name: name, plan: processor_plan) ||
        subscribed?(name: name, processor_plan: processor_plan)
    end

    def subscription(name: Pay.default_product_name)
      subscriptions.loaded? ? subscriptions.reverse.detect { |s| s.name == name } : subscriptions.for_name(name).last
    end

    def invoice!(options = {})
      ActiveSupport::Deprecation.warn("This will be removed in the next release. Use `@billable.payment_processor.invoice!` instead.")
      payment_processor.invoice!(options)
    end

    def upcoming_invoice
      ActiveSupport::Deprecation.warn("This will be removed in the next release. Use `@billable.payment_processor.upcoming_invoice` instead.")
      payment_processor.upcoming_invoice
    end

    def stripe?
      ActiveSupport::Deprecation.warn("This will be removed in the next release. Use `@billable.processor.stripe?` instead.")
      processor == "stripe"
    end

    def braintree?
      ActiveSupport::Deprecation.warn("This will be removed in the next release. Use `@billable.processor.braintree?` instead.")
      processor == "braintree"
    end

    def paypal?
      card_type == "PayPal"
    end

    def paddle?
      ActiveSupport::Deprecation.warn("This will be removed in the next release. Use `@billable.processor.paddle?` instead.")
      processor == "paddle"
    end

    def has_incomplete_payment?(name: Pay.default_product_name)
      subscription(name: name)&.has_incomplete_payment?
    end

    # Used for creating a Pay::Subscription in the database
    def create_pay_subscription(subscription, processor, name, plan, options = {})
      options[:quantity] ||= 1

      options.merge!(
        name: name || "default",
        processor: processor,
        processor_id: subscription.id,
        processor_plan: plan,
        trial_ends_at: payment_processor.trial_end_date(subscription),
        ends_at: nil
      )
      subscriptions.create!(options)
    end

    private

    def default_generic_trial?(name, plan)
      # Generic trials don't have plans or custom names
      plan.nil? && name == "default" && on_generic_trial?
    end

    def pay_fake_processor_is_allowed
      return unless processor == "fake_processor"
      errors.add(:processor, "must be a valid payment processor") unless pay_fake_processor_allowed?
    end
  end
end
