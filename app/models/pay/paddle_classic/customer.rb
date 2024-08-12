module Pay
  module PaddleClassic
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::PaddleClassic::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::PaddleClassic::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::PaddleClassic::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::PaddleClassic::PaymentMethod"

      def api_record
      end

      def update_api_record
      end

      def charge(amount, options = {})
        return unless subscription.processor_id
        raise Pay::Error, "A charge_name is required to create a one-time charge" if options[:charge_name].nil?

        response = PaddleClassic.client.charges.create(subscription_id: subscription.processor_id, amount: amount.to_f / 100, charge_name: options[:charge_name])

        attributes = {
          amount: (response[:amount].to_f * 100).to_i,
          paddle_receipt_url: response[:receipt_url],
          created_at: Time.zone.parse(response[:payment_date])
        }

        # Lookup subscription payment method details
        attributes.merge! Pay::PaddleClassic::PaymentMethod.payment_method_details_for(subscription_id: subscription.processor_id)

        charge = charges.find_or_initialize_by(processor_id: response[:invoice_id])
        charge.update(attributes)
        charge
      rescue ::Paddle::Error => e
        raise Pay::PaddleClassic::Error, e
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # pass
      end

      # Paddle does not use payment method tokens. The method signature has it here
      # to have a uniform API with the other payment processors.
      def add_payment_method(token = nil, default: true)
        Pay::PaddleClassic::PaymentMethod.sync(pay_customer: self)
      end
    end
  end
end
