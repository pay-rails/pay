module Pay
  module Billable
    module Stripe
      def stripe_customer
        if processor_id?
          ::Stripe::Customer.retrieve(processor_id)
        else
          create_stripe_customer
        end
      end

      def create_stripe_charge(amount, options={})
        args = {
          amount: amount,
          currency: 'usd',
          customer: customer.id,
        }.merge(options)

        ::Stripe::Charge.create(args)
      end

      def create_stripe_subscription(name, plan, options={})
        stripe_sub   = customer.subscriptions.create(plan: plan, trial_from_plan: true)
        subscription = create_subscription(stripe_sub, 'stripe', name, plan)
        subscription
      end

      def update_stripe_card(token)
        customer = stripe_customer
        token = ::Stripe::Token.retrieve(token)

        return if token.card.id == customer.default_source
        result = save_stripe_card(token, customer)
        self.card_token = nil
        result
      end

      def stripe_subscription(subscription_id)
        ::Stripe::Subscription.retrieve(subscription_id)
      end

      def stripe_invoice!
        return unless processor_id?
        ::Stripe::Invoice.create(customer: processor_id).pay
      end

      def stripe_upcoming_invoice
        ::Stripe::Invoice.upcoming(customer: processor_id)
      end

      def stripe?
        processor == "stripe"
      end

      def update_card_from_stripe
        customer = stripe_customer
        default_source_id = customer.default_source

        if default_source_id.present?
          card = customer.sources.data.find{ |s| s.id == default_source_id }
          update(
            card_brand: card.brand,
            card_last4: card.brand,
            card_exp_month: card.exp_month,
            card_exp_year: card.exp_year
          )

        # Customer has no default payment source
        else
          update(card_brand: nil, card_last4: nil)
        end
      end

      private

      def create_stripe_customer
        customer = ::Stripe::Customer.create(email: email, source: card_token)
        update(processor: 'stripe', processor_id: customer.id)

        # Update the user's card on file if a token was passed in
        source = customer.sources.data.first
        if source.present?
          update_stripe_card_on_file customer.sources.retrieve(source.id)
        end

        customer
      end

      def save_stripe_card(token, customer)
        card = customer.sources.create(source: token.id)
        customer.default_source = card.id
        customer.save
        update_stripe_card_on_file(card)
      end

      def stripe_trial_end_date(stripe_sub)
        stripe_sub.trial_end.present? ? Time.at(stripe_sub.trial_end) : nil
      end

      def update_stripe_card_on_file(card)
        update!(
          card_brand: card.brand,
          card_last4: card.last4,
          card_exp_month: card.exp_month,
          card_exp_year: card.exp_year
        )
      end
    end
  end
end
