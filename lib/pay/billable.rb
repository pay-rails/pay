module Pay
  module Billable
    extend ActiveSupport::Concern

    included do
      has_many :subscriptions, foreign_key: :owner_id

      attribute :card_token, :string
    end

    def subscribe(name = 'default', plan = 'default')
      return if subscribed?

      create_processor_customer

      subscription = subscriptions.new(
        name: name,
        processor: processor,
        processor_plan: plan
      )

      subscription.create_with_processor
    end

    def processor_customer(token = nil)
      if processor_id?
        customer = Stripe::Customer.retrieve(processor_id)
        update_card(token) if token.present?
      end

      customer
    end

    def update_card(token)
      customer = processor_customer
      token = Stripe::Token.retrieve(token)

      return if token.card.id == processor_customer.default_source

      card = customer.sources.create(source: token.id)
      customer.default_source = card.id
      customer.save

      update_with_card(card)
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

    private

    def update_with_card(card)
      update(
        card_brand: card.brand,
        card_last4: card.last4,
        card_exp_month: card.exp_month,
        card_exp_year: card.exp_year
      )
    end

    def create_processor_customer
      customer = Stripe::Customer.create(email: email, source: card_token)
      card = customer.sources.first
      update!(
        processor: 'stripe',
        processor_id: customer.id,
        card_token: card.id,
        card_brand: card.brand,
        card_last4: card.last4,
        card_exp_month: card.exp_month,
        card_exp_year: card.exp_year
      )
      customer
    end
  end
end
