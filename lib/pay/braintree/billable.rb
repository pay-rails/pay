module Pay
  module Braintree
    module Billable
      # Handles Billable#customer
      #
      # Returns Braintree::Customer
      def braintree_customer
        if processor_id?
          gateway.customer.find(processor_id)
        else
          result = gateway.customer.create(
            email: email,
            first_name: try(:first_name),
            last_name: try(:last_name),
            payment_method_nonce: card_token,
          )
          raise Pay::Error.new(result.message) unless result.success?

          update(processor: "braintree", processor_id: result.customer.id)

          if card_token.present?
            update_braintree_card_on_file result.customer.payment_methods.last
          end

          result.customer
        end
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end

      # Handles Billable#charge
      #
      # Returns a Pay::Charge
      def create_braintree_charge(amount, options = {})
        args = {
          amount: amount / 100.0,
          customer_id: customer.id,
          options: {submit_for_settlement: true},
        }.merge(options)

        result = gateway.transaction.sale(args)
        save_braintree_transaction(result.transaction) if result.success?
      rescue ::BraintreeError => e
        raise Error, e.message
      end

      # Handles Billable#subscribe
      #
      # Returns Pay::Subscription
      def create_braintree_subscription(name, plan, options = {})
        token = customer.payment_methods.find(&:default?).try(:token)
        raise Pay::Error, "Customer has no default payment method" if token.nil?

        # Standardize the trial period options
        if (trial_period_days = options.delete(:trial_period_days)) && trial_period_days > 0
          options.merge!(trial_period: true, trial_duration: trial_period_days, trial_duration_unit: :day)
        end

        subscription_options = options.merge(
          payment_method_token: token,
          plan_id: plan
        )

        result = gateway.subscription.create(subscription_options)
        raise Pay::Error.new(result.message) unless result.success?

        create_subscription(result.subscription, "braintree", name, plan, status: :active)
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end

      # Handles Billable#update_card
      #
      # Returns true if successful
      def update_braintree_card(token)
        result = gateway.payment_method.create(
          customer_id: processor_id,
          payment_method_nonce: token,
          options: {
            make_default: true,
            verify_card: true,
          }
        )
        raise Pay::Error.new(result.message) unless result.success?

        update_braintree_card_on_file result.payment_method
        update_subscriptions_to_payment_method(result.payment_method.token)
        true
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end

      def update_braintree_email!
        braintree_customer.update(
          email: email,
          first_name: try(:first_name),
          last_name: try(:last_name),
        )
      end

      def braintree_trial_end_date(subscription)
        return unless subscription.trial_period
        # Braintree returns dates without time zones, so we'll assume they're UTC
        Time.parse(subscription.first_billing_date).end_of_day
      end

      def update_subscriptions_to_payment_method(token)
        subscriptions.each do |subscription|
          if subscription.active?
            gateway.subscription.update(subscription.processor_id, {payment_method_token: token})
          end
        end
      end

      def braintree_subscription(subscription_id, options = {})
        gateway.subscription.find(subscription_id)
      end

      def braintree_invoice!(options = {})
        # pass
      end

      def braintree_upcoming_invoice
        # pass
      end

      def save_braintree_transaction(transaction)
        attrs = card_details_for_braintree_transaction(transaction)
        attrs[:amount] = transaction.amount.to_f * 100

        charge = charges.find_or_initialize_by(
          processor: :braintree,
          processor_id: transaction.id
        )
        charge.update(attrs)
        charge
      end

      private

      def gateway
        Pay.braintree_gateway
      end

      def update_braintree_card_on_file(payment_method)
        case payment_method
        when ::Braintree::CreditCard
          update!(
            card_type: payment_method.card_type,
            card_last4: payment_method.last_4,
            card_exp_month: payment_method.expiration_month,
            card_exp_year: payment_method.expiration_year
          )

        when ::Braintree::PayPalAccount
          update!(
            card_type: "PayPal",
            card_last4: payment_method.email
          )
        end

        # Clear the card token so we don't accidentally update twice
        self.card_token = nil
      end

      def card_details_for_braintree_transaction(transaction)
        case transaction.payment_instrument_type
        when "credit_card", "samsung_pay_card", "masterpass_card", "samsung_pay_card", "visa_checkout_card"
          payment_method = transaction.send("#{transaction.payment_instrument_type}_details")
          {
            card_type: payment_method.card_type,
            card_last4: payment_method.last_4,
            card_exp_month: payment_method.expiration_month,
            card_exp_year: payment_method.expiration_year,
          }

        when "paypal_account"
          {
            card_type: "PayPal",
            card_last4: transaction.paypal_details.payer_email,
            card_exp_month: nil,
            card_exp_year: nil,
          }

        when "android_pay_card"
          payment_method = transaction.android_pay_details
          {
            card_type: payment_method.source_card_type,
            card_last4: payment_method.source_card_last_4,
            card_exp_month: payment_method.expiration_month,
            card_exp_year: payment_method.expiration_year,
          }

        when "venmo_account"
          {
            card_type: "Venmo",
            card_last4: transaction.venmo_account_details.username,
            card_exp_month: nil,
            card_exp_year: nil,
          }

        when "apple_pay_card"
          payment_method = transaction.apple_pay_details
          {
            card_type: payment_method.card_type,
            card_last4: payment_method.last_4,
            card_exp_month: payment_method.expiration_month,
            card_exp_year: payment_method.expiration_year,
          }

        else
          {}
        end
      end
    end
  end
end
