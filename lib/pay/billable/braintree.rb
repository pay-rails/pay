module Pay
  module Billable
    module Braintree

      def braintree_customer(token=nil)
        if processor_id?
          result = Braintree::PaymentMethod.create(
            customer_id: processor_id,
            payment_method_nonce: card_token,
            options: {make_default: true}
          )

          if result.success?
            raise StandardError, result.inspect
          else
            customer = Braintree::Customer.find(processor_id)
          end

        else
          result = Braintree::Customer.create(
            email: email,
            payment_method_nonce: card_token,
          )

          if result.success?
            customer = result.customer
            update(processor: "braintree", processor_id: customer.id)
          else
            raise StandardError, result.inspect
          end

          customer
        end
      end

      def create_braintree_subscription(name="default")
        token  = braintree_customer.payment_methods.find{ |pm| pm.default? }.token
        result = Braintree::Subscription.create(
          payment_method_token: token,
          plan_id: plan,
        )

        if result.success?
          subscription = subscriptions.create(
            name: name || "default",
            processor: processor,
            processor_id: result.subscription.id,
            processor_plan: plan,
            trial_ends_at: stripe_sub.trial_end.present? ? Time.at(stripe_sub.trial_end) : nil,
            quantity: quantity || 1,
            ends_at: nil
          )
        else
          raise StandardError, result.inspect
        end

        subscription
      end

      def update_braintree_card(token)
      end

    end
  end
end
