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

    def customer(token=nil)
      send("#{processor}_customer", token)
    end

    def subscribe(name = 'default', plan = 'default', processor = 'stripe')
      return if subscribed?(name)
      update_card(card_token) if card_token.present?
      
      send("create_#{processor}_subscription", name)
    end

    def processor_customer(token = nil)
      if processor_id?
        customer = Stripe::Customer.retrieve(processor_id)
        update_card(token) if token.present?
      end

      customer
    end

    def update_card(token)
      send("update_#{processor}_card", token)
    end

    def subscribed?(name = 'default', plan = nil)
      subscription = subscription(name)

      return false if subscription.nil?
      return subscription.active? if plan.nil?

      subscription.active? && subscription.plan == plan
    end

    def subscription(name = 'default')
      subscriptions.where(name: name).last
    end
  end
end
