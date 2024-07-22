module Pay
  module Stripe
    class Billable
      include Rails.application.routes.url_helpers

      attr_reader :pay_customer

      delegate :processor_id,
        :processor_id?,
        :email,
        :customer_name,
        :payment_method_token,
        :payment_method_token?,
        :stripe_account,
        to: :pay_customer

      def self.default_url_options
        Rails.application.config.action_mailer.default_url_options || {}
      end

      def initialize(pay_customer)
        @pay_customer = pay_customer
      end

      # Returns a hash of attributes for the Stripe::Customer object
      def customer_attributes
        owner = pay_customer.owner

        attributes = case owner.class.pay_stripe_customer_attributes
        when Symbol
          owner.send(owner.class.pay_stripe_customer_attributes, pay_customer)
        when Proc
          owner.class.pay_stripe_customer_attributes.call(pay_customer)
        end

        # Guard against attributes being returned nil
        attributes ||= {}

        {email: email, name: customer_name}.merge(attributes)
      end

      # Retrieves a Stripe::Customer object
      #
      # Finds an existing Stripe::Customer if processor_id exists
      # Creates a new Stripe::Customer using `customer_attributes` if empty processor_id
      #
      # Updates the default payment method automatically if a payment_method_token is set
      #
      # Returns a Stripe::Customer object
      def customer
        stripe_customer = if processor_id?
          ::Stripe::Customer.retrieve({id: processor_id, expand: ["tax", "invoice_credit_balance"]}, stripe_options)
        else
          sc = ::Stripe::Customer.create(customer_attributes.merge(expand: ["tax"]), stripe_options)
          pay_customer.update!(processor_id: sc.id, stripe_account: stripe_account)
          sc
        end

        if payment_method_token?
          add_payment_method(payment_method_token, default: true)
          pay_customer.payment_method_token = nil
        end

        stripe_customer
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Syncs name and email to Stripe::Customer
      # You can also pass in other attributes that will be merged into the default attributes
      def update_customer!(**attributes)
        customer unless processor_id?
        ::Stripe::Customer.update(
          processor_id,
          customer_attributes.merge(attributes),
          stripe_options
        )
      end

      # Charges an amount to the customer's default payment method
      def charge(amount, options = {})
        add_payment_method(payment_method_token, default: true) if payment_method_token?

        payment_method = pay_customer.default_payment_method
        args = {
          confirm: true,
          payment_method: payment_method&.processor_id
        }.merge(options)

        payment_intent = create_payment_intent(amount, args)
        Pay::Payment.new(payment_intent).validate

        charge = payment_intent.latest_charge
        Pay::Stripe::Charge.sync(charge.id, object: charge)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Creates and returns a Stripe::PaymentIntent
      def create_payment_intent(amount, options = {})
        args = {
          amount: amount,
          currency: "usd",
          customer: processor_id,
          expand: ["latest_charge.refunds"],
          return_url: root_url
        }.merge(options)

        ::Stripe::PaymentIntent.create(args, stripe_options)
      end

      # Used for creating Stripe Terminal charges
      def terminal_charge(amount, options = {})
        create_payment_intent(amount, options.merge(payment_method_types: ["card_present"], capture_method: "manual"))
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        quantity = options.delete(:quantity)
        opts = {
          expand: ["pending_setup_intent", "latest_invoice.payment_intent", "latest_invoice.charge"],
          items: [plan: plan, quantity: quantity]
        }.merge(options)

        # Load the Stripe customer to verify it exists and update payment method if needed
        opts[:customer] = customer.id

        # Create subscription on Stripe
        stripe_sub = ::Stripe::Subscription.create(opts.merge(Pay::Stripe::Subscription.expand_options), stripe_options)

        # Save Pay::Subscription
        subscription = Pay::Stripe::Subscription.sync(stripe_sub.id, object: stripe_sub, name: name)

        # No trial, payment method requires SCA
        if options[:payment_behavior].to_s != "default_incomplete" && subscription.incomplete?
          Pay::Payment.new(stripe_sub.latest_invoice.payment_intent).validate
        end

        subscription
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def add_payment_method(payment_method_id, default: false)
        customer unless processor_id?
        payment_method = ::Stripe::PaymentMethod.attach(payment_method_id, {customer: processor_id}, stripe_options)

        if default
          ::Stripe::Customer.update(processor_id, {
            invoice_settings: {
              default_payment_method: payment_method.id
            }
          }, stripe_options)
        end

        save_payment_method(payment_method, default: default)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Save the Stripe::PaymentMethod to the database
      def save_payment_method(payment_method, default:)
        pay_payment_method = pay_customer.payment_methods.where(processor_id: payment_method.id).first_or_initialize

        attributes = Pay::Stripe::PaymentMethod.extract_attributes(payment_method).merge(default: default)

        # Ignore the payment method if it's already in the database
        pay_customer.payment_methods.where.not(id: pay_payment_method.id).update_all(default: false) if default
        pay_payment_method.update!(attributes)

        # Reload the Rails association
        pay_customer.reload_default_payment_method

        pay_payment_method
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

      def create_setup_intent(options = {})
        customer unless processor_id?
        ::Stripe::SetupIntent.create({
          customer: processor_id,
          usage: :off_session
        }.merge(options), stripe_options)
      end

      def trial_end_date(stripe_sub)
        # Times in Stripe are returned in UTC
        stripe_sub.trial_end.present? ? Time.at(stripe_sub.trial_end) : nil
      end

      # Syncs a customer's subscriptions from Stripe to the database.
      # Note that by default canceled subscriptions are NOT returned by Stripe. In order to include them, use `sync_subscriptions(status: "all")`.
      def sync_subscriptions(**options)
        subscriptions = ::Stripe::Subscription.list(options.with_defaults(customer: processor_id), stripe_options)
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
      # checkout(line_items: [{ price: "price_123" }, { price: "price_456" }])
      # checkout(line_items: "price_12345", allow_promotion_codes: true)
      #
      def checkout(**options)
        customer unless processor_id?
        args = {
          customer: processor_id,
          mode: "payment"
        }

        # Hosted (the default) checkout sessions require a success_url and cancel_url
        if ["", "hosted"].include? options[:ui_mode].to_s
          args[:success_url] = merge_session_id_param(options.delete(:success_url) || root_url)
          args[:cancel_url] = merge_session_id_param(options.delete(:cancel_url) || root_url)
        end

        if options[:return_url]
          args[:return_url] = merge_session_id_param(options.delete(:return_url))
        end

        # Line items are optional
        if (line_items = options.delete(:line_items))
          quantity = options.delete(:quantity) || 1

          args[:line_items] = Array.wrap(line_items).map { |item|
            if item.is_a? Hash
              item
            else
              {
                price: item,
                quantity: quantity
              }
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
        customer unless processor_id?
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
        customer unless processor_id?
        args = {
          customer: processor_id,
          return_url: options.delete(:return_url) || root_url
        }
        ::Stripe::BillingPortal::Session.create(args.merge(options), stripe_options)
      end

      def authorize(amount, options = {})
        charge(amount, options.merge(capture_method: :manual))
      end

      private

      # Options for Stripe requests
      def stripe_options
        {stripe_account: stripe_account}.compact
      end

      # Includes the `session_id` param for Stripe Checkout with existing params (and makes sure the curly braces aren't escaped)
      def merge_session_id_param(url)
        uri = URI.parse(url)
        uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s).to_h.merge("session_id" => "{CHECKOUT_SESSION_ID}").to_a)
        uri.to_s.gsub("%7BCHECKOUT_SESSION_ID%7D", "{CHECKOUT_SESSION_ID}")
      end
    end
  end
end
