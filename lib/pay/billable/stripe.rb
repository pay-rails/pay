module Pay
  module Billable
    module Stripe
      def stripe_customer(token=nil)
        if processor_id?
          customer = ::Stripe::Customer.retrieve(processor_id)
          update_card(token) if token.present?
        else
          customer = ::Stripe::Customer.create(email: email, source: token)
          update(processor: "stripe", processor_id: customer.id)
        end

        customer
      end

      def create_stripe_subscription(name="default")
        stripe_sub   = stripe_customer.subscriptions.create(plan: plan)

        subscription = subscriptions.create(
          name: name || "default",
          processor: processor,
          processor_id: stripe_sub.id,
          processor_plan: plan,
          trial_ends_at: stripe_sub.trial_end.present? ? Time.at(stripe_sub.trial_end) : nil,
          quantity: quantity || 1,
          ends_at: nil
        )
        subscription
      end

      def update_stripe_card(token)
        customer = stripe_customer
        token = ::Stripe::Token.retrieve(token)

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
    end
  end
end
