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
        pay_customer
      end

      def charge(amount, options = {})
        pay_customer.charges.create(
          processor_id: rand(100_000_000),
          amount: amount,
          data: {
            kind: :card,
            type: :fake,
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        )
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        pay_customer.subscriptions.create!(
          processor_id: rand(1_000_000),
          name: name,
          processor_plan: plan,
          status: :active,
          quantity: options.fetch(:quantity, 1)
        )
      end

      def update_payment_method(payment_method_id)
        pay_customer.update(
          data: {
            kind: :card,
            type: :fake,
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        )
      end
      alias_method :update_card, :update_payment_method

      def update_email!
        # pass
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
