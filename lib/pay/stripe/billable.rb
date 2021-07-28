module Pay
  module Stripe
    class Billable
      include Rails.application.routes.url_helpers

      attr_reader :billable

      delegate :processor_id,
        :processor_id?,
        :email,
        :customer_name,
        :card_token,
        :stripe_account,
        to: :billable

      class << self
        def default_url_options
          Rails.application.config.action_mailer.default_url_options || {}
        end
      end

      def initialize(billable)
        @billable = billable
      end

      # Handles Billable#customer
      #
      # Returns Stripe::Customer
      def customer
        stripe_customer = if processor_id?
          ::Stripe::Customer.retrieve(processor_id, stripe_options)
        else
          sc = ::Stripe::Customer.create({email: email, name: customer_name}, stripe_options)
          billable.update(processor: :stripe, processor_id: sc.id, stripe_account: stripe_account)
          sc
        end

        # Update the user's card on file if a token was passed in
        if card_token.present?
          payment_method = ::Stripe::PaymentMethod.attach(card_token, {customer: stripe_customer.id}, stripe_options)
          stripe_customer = ::Stripe::Customer.update(stripe_customer.id, {invoice_settings: {default_payment_method: payment_method.id}}, stripe_options)
          update_card_on_file(payment_method.card)
        end

        stripe_customer
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Handles Billable#charge
      #
      # Returns Pay::Charge
      def charge(amount, options = {})
        stripe_customer = customer
        args = {
          amount: amount,
          confirm: true,
          confirmation_method: :automatic,
          currency: "usd",
          customer: stripe_customer.id,
          payment_method: stripe_customer.invoice_settings.default_payment_method
        }.merge(options)

        payment_intent = ::Stripe::PaymentIntent.create(args, stripe_options)
        Pay::Payment.new(payment_intent).validate

        # Create a new charge object
        charge = payment_intent.charges.first
        Pay::Stripe::Charge.sync(charge.id, object: charge)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Handles Billable#subscribe
      #
      # Returns Pay::Subscription
      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        quantity = options.delete(:quantity) || 1
        opts = {
          expand: ["pending_setup_intent", "latest_invoice.payment_intent"],
          items: [plan: plan, quantity: quantity],
          off_session: true
        }.merge(options)

        # Inherit trial from plan unless trial override was specified
        opts[:trial_from_plan] = true unless opts[:trial_period_days]

        # Load the Stripe customer to verify it exists and update card if needed
        opts[:customer] = customer.id

        # Create subscription on Stripe
        stripe_sub = ::Stripe::Subscription.create(opts, stripe_options)

        # Save Pay::Subscription
        subscription = Pay::Stripe::Subscription.sync(stripe_sub.id, object: stripe_sub, name: name)

        # No trial, card requires SCA
        if subscription.incomplete?
          Pay::Payment.new(stripe_sub.latest_invoice.payment_intent).validate
        end

        subscription
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Handles Billable#update_card
      #
      # Returns true if successful
      def update_card(payment_method_id)
        stripe_customer = customer

        return true if payment_method_id == stripe_customer.invoice_settings.default_payment_method

        payment_method = ::Stripe::PaymentMethod.attach(payment_method_id, {customer: stripe_customer.id}, stripe_options)
        ::Stripe::Customer.update(stripe_customer.id, {invoice_settings: {default_payment_method: payment_method.id}}, stripe_options)

        update_card_on_file(payment_method.card)
        true
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def update_email!
        ::Stripe::Customer.update(processor_id, {email: email, name: customer_name}, stripe_options)
      end

      def processor_subscription(subscription_id, options = {})
        ::Stripe::Subscription.retrieve(options.merge(id: subscription_id), stripe_options)
      end

      def invoice!(options = {})
        return unless processor_id?
        ::Stripe::Invoice.create(options.merge(customer: processor_id), stripe_options).pay
      end

      def upcoming_invoice
        ::Stripe::Invoice.upcoming({customer: processor_id}, stripe_options)
      end

      # Used by webhooks when the customer or source changes
      def sync_card_from_stripe
        if (payment_method_id = customer.invoice_settings.default_payment_method)
          update_card_on_file ::Stripe::PaymentMethod.retrieve(payment_method_id, stripe_options).card
        else
          billable.update(card_type: nil, card_last4: nil)
        end
      end

      def create_setup_intent
        ::Stripe::SetupIntent.create({customer: processor_id, usage: :off_session}, stripe_options)
      end

      def trial_end_date(stripe_sub)
        # Times in Stripe are returned in UTC
        stripe_sub.trial_end.present? ? Time.at(stripe_sub.trial_end) : nil
      end

      # Save the card to the database as the user's current card
      def update_card_on_file(card)
        billable.update!(
          card_type: card.brand.capitalize,
          card_last4: card.last4,
          card_exp_month: card.exp_month,
          card_exp_year: card.exp_year
        )

        billable.card_token = nil
      end

      # Syncs a customer's subscriptions from Stripe to the database
      def sync_subscriptions
        subscriptions = ::Stripe::Subscription.list({customer: customer}, stripe_options)
        subscriptions.map do |subscription|
          Pay::Stripe::Subscription.sync(subscription.id)
        end
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # https://stripe.com/docs/api/checkout/sessions/create
      #
      # checkout(mode: "payment")
      # checkout(mode: "setup")
      # checkout(mode: "subscription")
      #
      # checkout(line_items: "price_12345", quantity: 2)
      # checkout(line_items [{ price: "price_123" }, { price: "price_456" }])
      # checkout(line_items, "price_12345", allow_promotion_codes: true)
      #
      def checkout(**options)
        args = {
          customer: processor_id,
          payment_method_types: ["card"],
          mode: "payment",
          # These placeholder URLs will be replaced in a following step.
          success_url: options.delete(:success_url) || root_url,
          cancel_url: options.delete(:cancel_url) || root_url
        }

        # Line items are optional
        if (line_items = options.delete(:line_items))
          args[:line_items] = Array.wrap(line_items).map { |item|
            if item.is_a? Hash
              item
            else
              {price: item, quantity: options.fetch(:quantity, 1)}
            end
          }
        end

        ::Stripe::Checkout::Session.create(args.merge(options), stripe_options)
      end

      # https://stripe.com/docs/api/checkout/sessions/create
      #
      # checkout_charge(amount: 15_00, name: "T-shirt", quantity: 2)
      #
      def checkout_charge(amount:, name:, quantity: 1, **options)
        currency = options.delete(:currency) || "usd"
        checkout(
          line_items: {
            price_data: {
              currency: currency,
              product_data: {name: name},
              unit_amount: amount
            },
            quantity: quantity
          },
          **options
        )
      end

      def billing_portal(**options)
        args = {
          customer: processor_id,
          return_url: options.delete(:return_url) || root_url
        }
        ::Stripe::BillingPortal::Session.create(args.merge(options), stripe_options)
      end

      private

      # Options for Stripe requests
      def stripe_options
        {stripe_account: stripe_account}.compact
      end
    end
  end
end
