module Pay
  module Billable
    module Braintree
       def braintree_customer
         if processor_id?
           ::Braintree::Customer.find(processor_id)
         else
           result = ::Braintree::Customer.create(email: email, payment_token_nonce: card_token)
           raise StandardError, result.inspect unless result.success?

           update(processor: 'braintree', processor_id: result.customer.id)

           if card_token.present?
             update_braintree_card_on_file result.customer.payment_methods[0]
           end

           result.customer
         end
       end

      def create_braintree_subscription(name, plan)
        token = braintree_customer.payment_methods.find(&:default?).token

        result = ::Braintree::Subscription.create(
          payment_method_token: token,
          plan_id: plan
        )
        raise StandardError, result.inspect unless result.success?

        create_subscription(result.subscription, 'braintree', name, plan)
      end

      def update_braintree_card(token)
        result = ::Braintree::PaymentMethod.create(
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
            ::Braintree::Subscription.update(subscription.processor_id, { payment_method_token: token })
          end
        end
      end

      def braintree_subscription(subscription_id)
        ::Braintree::Subscription.find(subscription_id)
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

        update!(
        )
      end
    end
  end
end
