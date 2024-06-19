module Pay
  module FakeProcessor
    class Billable
      attr_reader :pay_customer

      delegate :processor_id,
        :processor_id?,
        :email,
        :customer_name,
        :card_token,
        to: :pay_customer

      def initialize(pay_customer)
        @pay_customer = pay_customer
      end

      def customer
        pay_customer.update!(processor_id: NanoId.generate) unless processor_id?
        pay_customer
      end

      def update_customer!(**attributes)
        # return customer to fake an update
        customer
      end

      def charge(amount, options = {})
        # Make to generate a processor_id
        customer

        valid_attributes = options.slice(*Pay::Charge.attribute_names.map(&:to_sym))
        attributes = {
          processor_id: NanoId.generate,
          amount: amount,
          data: {
            payment_method_type: :card,
            brand: "Fake",
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        }.deep_merge(valid_attributes)
        pay_customer.charges.create!(attributes)
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # Make to generate a processor_id
        customer
        attributes = options.merge(
          processor_id: NanoId.generate,
          name: name,
          processor_plan: plan,
          status: :active,
          quantity: options.fetch(:quantity, 1)
        )

        if (trial_period_days = attributes.delete(:trial_period_days))
          attributes[:trial_ends_at] = trial_period_days.to_i.days.from_now
        end

        attributes.delete(:promotion_code)

        pay_customer.subscriptions.create!(attributes)
      end

      def add_payment_method(payment_method_id, default: false)
        # Make to generate a processor_id
        customer

        pay_payment_method = pay_customer.payment_methods.create!(
          processor_id: NanoId.generate,
          default: default,
          type: :card,
          data: {
            brand: "Fake",
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        )

        if default
          pay_customer.payment_methods.where.not(id: pay_payment_method.id).update_all(default: false)
          pay_customer.reload_default_payment_method
        end

        pay_payment_method
      end

      def processor_subscription(subscription_id, options = {})
        pay_customer.subscriptions.find_by(processor_id: subscription_id)
      end

      def trial_end_date(subscription)
        Date.today
      end
    end
  end
end
