module Pay
  module Stripe
    module Billable
      # Handles Billable#customer
      def stripe_customer
        if processor_id?
          ::Stripe::Customer.retrieve(processor_id)
        else
          create_stripe_customer
        end
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      # Handles Billable#charge
      def create_stripe_charge(amount, options={})
        args = {
          amount: amount,
          currency: 'usd',
          customer: customer.id,
          description: customer_name,
        }.merge(options)

        stripe_charge = ::Stripe::Charge.create(args)

        # Save the charge to the db
        Pay::Stripe::Webhooks::ChargeSucceeded.new.create_charge(self, stripe_charge)
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      # Handles Billable#subscribe
      def create_stripe_subscription(name, plan, options={})
        stripe_sub   = customer.subscriptions.create(plan: plan, trial_from_plan: true)
        subscription = create_subscription(stripe_sub, 'stripe', name, plan)
        subscription
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      # Handles Billable#update_card
      def update_stripe_card(token)
        customer = stripe_customer
        token = ::Stripe::Token.retrieve(token)

        return if token.card.id == customer.default_source

        card = customer.sources.create(source: token.id)
        customer.default_source = card.id
        customer.save

        update_stripe_card_on_file(card)
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      def update_stripe_email!
        customer = stripe_customer
        customer.email = email
        customer.description = customer_name
        customer.save
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

      # Used by webhooks when the customer or source changes
      def sync_card_from_stripe
        stripe_cust = stripe_customer
        default_source_id = stripe_cust.default_source

        if default_source_id.present?
          card = stripe_customer.sources.data.find{ |s| s.id == default_source_id }
          update(
            card_type:      card.brand,
            card_last4:     card.last4,
            card_exp_month: card.exp_month,
            card_exp_year:  card.exp_year
          )

        # Customer has no default payment source
        else
          update(card_type: nil, card_last4: nil)
        end
      end

      private

      def create_stripe_customer
        customer = ::Stripe::Customer.create(email: email, source: card_token, description: customer_name)
        update(processor: 'stripe', processor_id: customer.id)

        # Update the user's card on file if a token was passed in
        source = customer.sources.data.first
        if source.present?
          update_stripe_card_on_file customer.sources.retrieve(source.id)
        end

        customer
      end

      def stripe_trial_end_date(stripe_sub)
        stripe_sub.trial_end.present? ? Time.at(stripe_sub.trial_end) : nil
      end

      # Save the card to the database as the user's current card
      def update_stripe_card_on_file(card)
        update!(
          card_type:      card.brand,
          card_last4:     card.last4,
          card_exp_month: card.exp_month,
          card_exp_year:  card.exp_year
        )

        self.card_token = nil
      end
    end
  end
end
