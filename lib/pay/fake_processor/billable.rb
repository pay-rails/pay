module Pay
  module FakeProcessor
    class Billable
      attr_reader :billable

      delegate :processor_id,
        :processor_id?,
        :email,
        :customer_name,
        :card_token,
        to: :billable

      def initialize(billable)
        @billable = billable
      end

      def customer
        billable
      end

      def charge(amount, options = {})
        billable.charges.create(
          processor: :fake_processor,
          processor_id: rand(100_000_000),
          amount: amount,
          card_type: :fake,
          card_last4: 1234,
          card_exp_month: Date.today.month,
          card_exp_year: Date.today.year
        )
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        subscription = OpenStruct.new id: rand(1_000_000)
        billable.create_pay_subscription(subscription, :fake_processor, name, plan, status: :active, quantity: options.fetch(:quantity, 1))
      end

      def update_card(payment_method_id)
        billable.update(
          card_type: :fake,
          card_last4: 1234,
          card_exp_month: Date.today.month,
          card_exp_year: Date.today.year
        )
      end

      def update_email!
        # pass
      end

      def processor_subscription(subscription_id, options = {})
        billable.subscriptions.find_by(processor: :fake_processor, processor_id: subscription_id)
      end

      def trial_end_date(subscription)
        Date.today
      end
    end
  end
end
