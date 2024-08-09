module Pay
  module Stripe
    class Customer < Customer
      # Returns a hash of attributes for the Stripe::Customer object
      def customer_attributes
        attributes = case owner.class.pay_stripe_customer_attributes
        when Symbol
          owner.send(owner.class.pay_stripe_customer_attributes, self)
        when Proc
          owner.class.pay_stripe_customer_attributes.call(self)
        end

        # Guard against attributes being returned nil
        attributes ||= {}

        {email: email, name: customer_name}.merge(attributes)
      end

      def api_record
        with_lock do
          if processor_id?
            ::Stripe::Customer.retrieve({id: processor_id, expand: ["tax", "invoice_credit_balance"]}, stripe_options)
          else
            ::Stripe::Customer.create(customer_attributes.merge(expand: ["tax"]), stripe_options).tap do |customer|
              update!(processor_id: customer.id, stripe_account: stripe_account)
            end
          end
        end
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def update_api_record(**attributes)
        api_record unless processor_id?
        ::Stripe::Customer.update(processor_id, customer_attributes.merge(attributes), stripe_options)
      end

      # Charges an amount to the customer's default payment method
      def charge(amount, options = {})
        args = {confirm: true, payment_method: default_payment_method&.processor_id}.merge(options)
        payment_intent = create_payment_intent(amount, args)

        Pay::Payment.new(payment_intent).validate

        charge = payment_intent.latest_charge
        Pay::Stripe::Charge.sync(charge.id, object: charge)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end
    end
  end
end
