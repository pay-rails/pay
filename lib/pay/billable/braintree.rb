module Pay
  module Billable
    module Braintree
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

          update(processor: 'braintree', processor_id: result.customer.id)

          if card_token.present?
            update_braintree_card_on_file result.customer.payment_methods.last
          end

          result.customer
        end
      end

      def create_braintree_charge(amount, options={})
        args = {
          amount: amount / 100.0,
          customer_id: customer.id,
          options: { submit_for_settlement: true }
        }.merge(options)

        result = gateway.transaction.sale(args)
        save_braintree_transaction(result.transaction) if result.success?
        result
      end

      def create_braintree_subscription(name, plan, options={})
        token = customer.payment_methods.find(&:default?).try(:token)
        raise Pay::Error, "Customer has no default payment method" if token.nil?

        subscription_options = options.merge(
          payment_method_token: token,
          plan_id: plan
        )

        result = gateway.subscription.create(subscription_options)
        raise Pay::Error.new(result.message) unless result.success?

        create_subscription(result.subscription, 'braintree', name, plan)
      end

      def update_braintree_card(token)
        result = gateway.payment_method.create(
          customer_id: processor_id,
          payment_method_nonce: token,
          options: {
            make_default: true,
            verify_card: true
          }
        )
        raise Pay::Error.new(result.message) unless result.success?

        self.card_token = nil
        update_braintree_card_on_file result.payment_method
        update_subscriptions_to_payment_method(result.payment_method.token)
      end

      def braintree_trial_end_date(subscription)
        return unless subscription.trial_period
        Time.zone.parse(subscription.first_billing_date)
      end

      def update_subscriptions_to_payment_method(token)
        subscriptions.each do |subscription|
          if subscription.active?
            gateway.subscription.update(subscription.processor_id, { payment_method_token: token })
          end
        end
      end

      def braintree_subscription(subscription_id)
        gateway.subscription.find(subscription_id)
      end

      def braintree_invoice!
        # pass
      end

      def braintree_upcoming_invoice
        # pass
      end

      def braintree?
        processor == "braintree"
      end

      def paypal?
        braintree? && card_brand == "PayPal"
      end

      def save_braintree_transaction(transaction)
        attrs = card_details_for_braintree_transaction(transaction)
        attrs.merge!(amount: transaction.amount.to_f * 100)

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
              card_brand: payment_method.card_type,
              card_last4: payment_method.last_4,
              card_exp_month: payment_method.expiration_month,
              card_exp_year: payment_method.expiration_year
            )

          when ::Braintree::PayPalAccount
            update!(
              card_brand: "PayPal",
              card_last4: payment_method.email
            )
          end
        end

        def card_details_for_braintree_transaction(transaction)
          case transaction.payment_instrument_type
          when "credit_card", "samsung_pay_card", "masterpass_card", "samsung_pay_card", "visa_checkout_card"
            payment_method = transaction.send("#{transaction.payment_instrument_type}_details")
            {
              card_type:      payment_method.card_type,
              card_last4:     payment_method.last_4,
              card_exp_month: payment_method.expiration_month,
              card_exp_year:  payment_method.expiration_year,
            }

          when "paypal_account"
            {
              card_type: "PayPal",
              card_last4: transaction.paypal_details.payer_email,
            }

          when "android_pay_card"
            payment_method = transaction.android_pay_details
            {
              card_type:      payment_method.source_card_type,
              card_last4:     payment_method.source_card_last_4,
              card_exp_month: payment_method.expiration_month,
              card_exp_year:  payment_method.expiration_year,
            }

          when "venmo_account"
            {
              card_type: "Venmo",
              card_last4: transaction.venmo_account_details.username
            }

          when "apple_pay_card"
            payment_method = transaction.apple_pay_details
            {
              card_type:      payment_method.card_type,
              card_last4:     payment_method.last_4,
              card_exp_month: payment_method.expiration_month,
              card_exp_year:  payment_method.expiration_year,
            }

          else
            {}
          end
        end
    end
  end
end
