require 'pay/billable/stripe'
require 'pay/billable/braintree'

module Pay
  module Billable
    extend ActiveSupport::Concern

    included do
      include Pay::Billable::Stripe
      include Pay::Billable::Braintree

      has_many :subscriptions, foreign_key: :owner_id

      attribute :plan, :string
      attribute :quantity, :integer
      attribute :card_token, :string
    end

    def customer
      check_for_processor
      send("#{processor}_customer")
    end

    def subscribe(name = 'default', plan = 'default', processor = 'stripe')
      self.processor = processor
      send("create_#{processor}_subscription", name, plan)
    end

    def update_card(token)
      check_for_processor
      send("update_#{processor}_card", token)
    end

    def processor_subscription(subscription_id)
      check_for_processor
      send("#{processor}_subscription", subscription_id)
    end

    def subscribed?(name = 'default', plan = nil)
      subscription = subscription(name)

      return false if subscription.nil?
      return subscription.active? if plan.nil?

      subscription.active? && subscription.plan == plan
    end

    def subscription(name = 'default')
      subscriptions.for_name(name).last
    end

    def invoice!
      send("#{processor}_invoice!")
    end

    def upcoming_invoice
      send("#{processor}_upcoming_invoice")
    end

    private

    def check_for_processor
      raise StandardError, 'No processor selected' unless processor
    end

    def create_subscription(subscription, processor, name, plan, qty = 1)
      subscriptions.create!(
        name: name || 'default',
        processor: processor,
        processor_id: subscription.id,
        processor_plan: plan,
        trial_ends_at: trial_end_date(subscription),
        quantity: qty,
        ends_at: nil
      )
    end

    def update_card_on_file(card)
      update!(
        card_brand: card.brand,
        card_last4: card.last4,
        card_exp_month: card.exp_month,
        card_exp_year: card.exp_year
      )
    end
  end
end
