module Pay
  module Billable
    extend ActiveSupport::Concern

    included do
      has_many :subscriptions

      attribute :plan, :string
      attribute :card_token, :string
    end

    def processor_customer(token=nil)
      if processor == "stripe"
        if processor_id?
          customer = Stripe::Customer.retrieve(processor_id)
          update_card(token) if token.present?
        else
          customer = Stripe::Customer.create(email: email, source: token)
          update(processor: "stripe", processor_id: customer.id)
        end
      else
        customer = nil
      end

      customer
    end

    def update_card(token)
      customer = processor_customer
      token = Stripe::Token.retrieve(token)

      if token.card.id != customer.default_source
        card = customer.sources.create(source: token.id)
        customer.default_source = card.id
        customer.save

        update(
          card_brand: card.brand,
          card_last4: card.last4,
          card_exp_month: card.exp_month,
          card_exp_year: card.exp_year
        )
      end
    end

    def subscribed?(name="default", plan=nil)
      subscription = subscription(name)

      return false if subscription.nil?
      return subscription.active? if plan.nil?

      subscription.active? && subscription.plan == plan
    end

    def subscription(name="default")
      subscriptions.where(name: name).last
    end

    def create_subscription(name="default", processor="stripe")
      return if subscribed?(name)
      subscriptions.new(name: name, processor: processor, processor_plan: plan, card_token: card_token).create_with_processor
    end
  end
end
