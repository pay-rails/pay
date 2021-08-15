module Pay
  module Braintree
    class Billable
      attr_reader :pay_customer

      delegate :processor_id,
        :processor_id?,
        :email,
        :customer_name,
        :payment_method_token,
        :payment_method_token?,
        to: :pay_customer

      def initialize(pay_customer)
        @pay_customer = pay_customer
      end

      # Retrieve the Braintree::Customer object
      #
      # - If no processor_id is present, creates a Customer.
      # - When 'payment_method_token' is present, it will also set the default payment method
      def customer
        if processor_id?
          customer = gateway.customer.find(processor_id)

          if payment_method_token?
            add_payment_method(payment_method_token, default: true)
            pay_customer.payment_method_token = nil
          end

          customer
        else
          result = gateway.customer.create(email: email, first_name: try(:first_name), last_name: try(:last_name), payment_method_nonce: payment_method_token)
          raise Pay::Braintree::Error, result unless result.success?
          pay_customer.update!(processor_id: result.customer.id)

          if payment_method_token?
            save_payment_method(result.customer.payment_methods.last, default: true)
            pay_customer.payment_method_token = nil
          end

          result.customer
        end
      rescue ::Braintree::AuthorizationError => e
        raise Pay::Braintree::AuthorizationError, e
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end

      def charge(amount, options = {})
        args = {
          amount: amount.to_i / 100.0,
          customer_id: customer.id,
          options: {submit_for_settlement: true}
        }.merge(options)

        result = gateway.transaction.sale(args)
        raise Pay::Braintree::Error, result unless result.success?

        save_transaction(result.transaction)
      rescue ::Braintree::AuthorizationError => e
        raise Pay::Braintree::AuthorizationError, e
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
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
        raise Pay::Braintree::Error, result unless result.success?

        pay_customer.subscriptions.create(
          name: name,
          processor_id: result.subscription.id,
          processor_plan: plan,
          status: :active,
          trial_ends_at: trial_end_date(result.subscription),
          ends_at: nil
        )
      rescue ::Braintree::AuthorizationError => e
        raise Pay::Braintree::AuthorizationError, e
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end

      def add_payment_method(token, default: false)
        customer unless processor_id?

        result = gateway.payment_method.create(
          customer_id: processor_id,
          payment_method_nonce: token,
          options: {
            make_default: true,
            verify_card: true
          }
        )
        raise Pay::Braintree::Error, result unless result.success?

        pay_payment_method = save_payment_method(result.payment_method, default: default)

        # Update existing subscriptions to the new payment method
        pay_customer.subscriptions.each do |subscription|
          if subscription.active?
            gateway.subscription.update(subscription.processor_id, {payment_method_token: token})
          end
        end

        pay_payment_method
      rescue ::Braintree::AuthorizationError => e
        raise Pay::Braintree::AuthorizationError, e
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end

      def update_email!
        gateway.customer.update(processor_id, email: email, first_name: try(:first_name), last_name: try(:last_name))
      end

      def trial_end_date(subscription)
        return unless subscription.trial_period
        # Braintree returns dates without time zones, so we'll assume they're UTC
        subscription.first_billing_date.end_of_day
      end

      def processor_subscription(subscription_id, options = {})
        gateway.subscription.find(subscription_id)
      end

      def save_transaction(transaction)
        attrs = card_details_for_braintree_transaction(transaction)
        attrs[:amount] = transaction.amount.to_f * 100

        # Associate charge with subscription if we can
        if transaction.subscription_id
          attrs[:subscription] = pay_customer.subscriptions.find_by(processor_id: transaction.subscription_id)
        end

        charge = pay_customer.charges.find_or_initialize_by(
          processor_id: transaction.id,
          currency: transaction.currency_iso_code,
          application_fee_amount: transaction.service_fee_amount
        )
        charge.update(attrs)
        charge
      end

      private

      def gateway
        Pay.braintree_gateway
      end

      def save_payment_method(payment_method, default:)
        attributes = case payment_method
                     when ::Braintree::CreditCard, ::Braintree::ApplePayCard, ::Braintree::GooglePayCard, ::Braintree::SamsungPayCard, ::Braintree::VisaCheckoutCard
                       {
                         payment_method_type: :card,
                         brand: payment_method.card_type,
                         last4: payment_method.last_4,
                         exp_month: payment_method.expiration_month,
                         exp_year: payment_method.expiration_year
                       }

                     when ::Braintree::PayPalAccount
                       {
                         payment_method_type: :paypal,
                         brand: "PayPal",
                         email: payment_method.email
                       }
                     when ::Braintree::VenmoAccount
                       {
                         payment_method_type: :venmo,
                         brand: "Venmo",
                         username: payment_method.username
                       }
                     when ::Braintree::UsBankAccount
                       {
                         payment_method_type: "us_bank_account",
                         bank: payment_method.bank_name,
                         last4: payment_method.last_4
                       }
                     else
                       {
                         payment_method_type: payment_method.class.name.demodulize.underscore
                       }
        end

        pay_payment_method = pay_customer.payment_methods.where(processor_id: payment_method.token).first_or_initialize

        pay_customer.payment_methods.update_all(default: false) if default
        pay_payment_method.update!(attributes.merge(default: default))

        # Reload the Rails association
        pay_customer.reload_default_payment_method if default

        pay_payment_method
      end

      def card_details_for_braintree_transaction(transaction)
        case transaction.payment_instrument_type
        when "android_pay_card", "apple_pay_card", "credit_card", "google_pay_card", "samsung_pay_card", "visa_checkout_card"
          # Lookup the attribute with the payment method details by name
          attribute_name = transaction.payment_instrument_type

          # The attribute name for Apple and Google Pay don't include _card for some reason
          if ["apple_pay_card", "google_pay_card"].include?(transaction.payment_instrument_type)
            attribute_name = attribute_name.split("_card").first

          # Android Pay was renamed to Google Pay, but test nonces still use android_pay_card
          elsif attribute_name == "android_pay_card"
            attribute_name = "google_pay"
          end

          # Retrieve payment method details from transaction
          payment_method = transaction.send("#{attribute_name}_details")

          {
            payment_method_type: :card,
            brand: payment_method.card_type,
            last4: payment_method.last_4,
            exp_month: payment_method.expiration_month,
            exp_year: payment_method.expiration_year
          }

        when "paypal_account"
          {
            payment_method_type: :paypal,
            brand: "PayPal",
            last4: transaction.paypal_details.payer_email,
            exp_month: nil,
            exp_year: nil
          }

        when "venmo_account"
          {
            payment_method_type: :venmo,
            brand: "Venmo",
            last4: transaction.venmo_account_details.username,
            exp_month: nil,
            exp_year: nil
          }

        else
          {payment_method_type: "unknown"}
        end
      end
    end
  end
end
