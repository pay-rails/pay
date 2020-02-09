require "pay/billable/sync_email"

module Pay
  module Billable
    extend ActiveSupport::Concern

    included do
      include Pay::Billable::SyncEmail

      has_many :charges, class_name: Pay.chargeable_class, foreign_key: :owner_id, inverse_of: :owner
      has_many :subscriptions, class_name: Pay.subscription_class, foreign_key: :owner_id, inverse_of: :owner

      attribute :plan, :string
      attribute :quantity, :integer
      attribute :card_token, :string
    end

    def processor=(value)
      super(value)
      self.processor_id = nil if processor_changed?
    end

    def customer
      check_for_processor
      raise Pay::Error, "Email is required to create a customer" if email.nil?

      customer = send("#{processor}_customer")
      update_card(card_token) if card_token.present?
      customer
    end

    def customer_name
      [try(:first_name), try(:last_name)].compact.join(" ")
    end

    def charge(amount_in_cents, options = {})
      check_for_processor
      send("create_#{processor}_charge", amount_in_cents, options)
    end

    def subscribe(name: "default", plan: "default", **options)
      check_for_processor
      send("create_#{processor}_subscription", name, plan, options)
    end

    def update_card(token)
      check_for_processor
      customer if processor_id.nil?
      send("update_#{processor}_card", token)
    end

    def on_trial?(name: "default", plan: nil)
      return true if default_generic_trial?(name, plan)

      sub = subscription(name: name)
      return sub&.on_trial? if plan.nil?

      sub&.on_trial? && sub.processor_plan == plan
    end

    def on_generic_trial?
      trial_ends_at? && trial_ends_at > Time.zone.now
    end

    def processor_subscription(subscription_id, options = {})
      check_for_processor
      send("#{processor}_subscription", subscription_id, options)
    end

    def subscribed?(name: "default", processor_plan: nil)
      subscription = subscription(name: name)

      return false if subscription.nil?
      return subscription.active? if processor_plan.nil?

      subscription.active? && subscription.processor_plan == processor_plan
    end

    def on_trial_or_subscribed?(name: "default", processor_plan: nil)
      on_trial?(name: name, plan: processor_plan) ||
        subscribed?(name: name, processor_plan: processor_plan)
    end

    def subscription(name: "default")
      subscriptions.for_name(name).last
    end

    def invoice!(options = {})
      send("#{processor}_invoice!", options)
    end

    def upcoming_invoice
      send("#{processor}_upcoming_invoice")
    end

    def stripe?
      processor == "stripe"
    end

    def braintree?
      processor == "braintree"
    end

    def paypal?
      braintree? && card_type == "PayPal"
    end

    def has_incomplete_payment?(name: "default")
      subscription(name: name)&.has_incomplete_payment?
    end

    private

    def check_for_processor
      raise StandardError, "No payment processor selected. Make sure to set the #{Pay.billable_class}'s `processor` attribute to either 'stripe' or 'braintree'." unless processor
    end

    # Used for creating a Pay::Subscription in the database
    def create_subscription(subscription, processor, name, plan, options = {})
      options[:quantity] ||= 1

      options.merge!(
        name: name || "default",
        processor: processor,
        processor_id: subscription.id,
        processor_plan: plan,
        trial_ends_at: send("#{processor}_trial_end_date", subscription),
        ends_at: nil,
      )
      subscriptions.create!(options)
    end

    def default_generic_trial?(name, plan)
      # Generic trials don't have plans or custom names
      plan.nil? && name == "default" && on_generic_trial?
    end
  end
end
