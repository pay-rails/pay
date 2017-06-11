module Pay
  module Billable
    module Stripe
      def stripe_customer
        if processor_id?
          customer = ::Stripe::Customer.retrieve(processor_id)
        else
          customer = ::Stripe::Customer.create(email: email, source: card_token)
          update(processor: 'stripe', processor_id: customer.id)
        end

        customer
      end

      def create_stripe_subscription(name, plan)
        stripe_sub = stripe_customer.subscriptions.create(plan: plan)
        subscription = create_subscription(stripe_sub, 'stripe', name, plan)
        subscription
      end

      def update_stripe_card(token)
        customer = stripe_customer
        token = ::Stripe::Token.retrieve(token)

        return if token.card.id == customer.default_source
        save_stripe_card(token, customer)
      end

      def stripe_subscription(subscription_id)
        ::Stripe::Subscription.retrieve(subscription_id)
      end

      private

      def save_stripe_card(token, customer)
        card = customer.sources.create(source: token.id)
        customer.default_source = card.id
        customer.save
        update_card_on_file(card)
      end

      def trial_end_date(stripe_sub)
        stripe_sub.trial_end.present? ? Time.at(stripe_sub.trial_end) : nil
      end
    end
  end
end
