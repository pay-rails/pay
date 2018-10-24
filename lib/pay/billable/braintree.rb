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
            last_name: try(:last_name)
          )
          raise Pay::Error.new(result) unless result.success?

          update(processor: 'braintree', processor_id: result.customer.id)

          if card_token.present?
            update_braintree_card_on_file result.customer.payment_methods[0]
          end

          result.customer
        end
      end

      def create_braintree_subscription(name, plan, options={})
        token = customer.payment_methods.find(&:default?).token

        subscription_options = options.merge(
          payment_method_token: token,
          plan_id: plan
        )

        result = gateway.subscription.create(subscription_options)
        raise Pay::Error.new(result) unless result.success?

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
        raise Pay::Error.new(result) unless result.success?

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
    end
  end
end
