module Pay
  module Billable
    module Braintree
      def gateway
        Pay.braintree_gateway
      end

      def braintree_customer
        if processor_id?
          gateway.customer.find(processor_id)
        else
          result = gateway.customer.create(email: email, payment_method_nonce: card_token)
          raise StandardError, result.inspect unless result.success?

          update(processor: 'braintree', processor_id: result.customer.id)

          if card_token.present?
            update_braintree_card_on_file result.customer.payment_methods[0]
          end

          result.customer
        end
      end

      def create_braintree_subscription(name, plan)
        token = customer.payment_methods.find(&:default?).token

        result = gateway.subscription.create(
          payment_method_token: token,
          plan_id: plan
        )
        raise StandardError, result.inspect unless result.success?

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
        raise StandardError, result.inspect unless result.success?

        self.card_token = nil
        update_braintree_card_on_file result.payment_method
        update_subscriptions_to_payment_method(result.payment_method.token)
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

      private

      def update_braintree_card_on_file(payment_method)
        puts
        puts
        p payment_method.class
        puts
        puts

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
