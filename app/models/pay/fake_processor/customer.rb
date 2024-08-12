module Pay
  module FakeProcessor
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::FakeProcessor::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::FakeProcessor::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::FakeProcessor::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::FakeProcessor::PaymentMethod"

      def api_record
        update!(processor_id: NanoId.generate) unless processor_id?
        self
      end

      def update_api_record(**attributes)
        self
      end

      def charge(amount, options = {})
        # Make to generate a processor_id
        api_record

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
        charges.create!(attributes)
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # Make to generate a processor_id
        api_record
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

        subscriptions.create!(attributes)
      end

      def add_payment_method(payment_method_id, default: false)
        # Make to generate a processor_id
        api_record

        pay_payment_method = payment_methods.create!(
          processor_id: NanoId.generate,
          default: default,
          payment_method_type: :card,
          data: {
            brand: "Fake",
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        )

        if default
          payment_methods.where.not(id: pay_payment_method.id).update_all(default: false)
          reload_default_payment_method
        end

        pay_payment_method
      end
    end
  end
end
