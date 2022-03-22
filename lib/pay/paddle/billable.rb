module Pay
  module Paddle
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
        # pass
      end

      def update_customer!
        # pass
      end

      def charge(amount, options = {})
        subscription = pay_customer.subscription
        return unless subscription.processor_id
        raise Pay::Error, "A charge_name is required to create a one-time charge" if options[:charge_name].nil?

        response = PaddlePay::Subscription::Charge.create(subscription.processor_id, amount.to_f / 100, options[:charge_name], options)

        attributes = {
          amount: (response[:amount].to_f * 100).to_i,
          paddle_receipt_url: response[:receipt_url],
          created_at: Time.zone.parse(response[:payment_date])
        }

        # Lookup subscription payment method details
        attributes.merge! Pay::Paddle::PaymentMethod.payment_method_details_for(subscription_id: subscription.processor_id)

        charge = pay_customer.charges.find_or_initialize_by(processor_id: response[:invoice_id])
        charge.update(attributes)
        charge
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # pass
      end

      def add_payment_method(token, default: true)
        Pay::Paddle::PaymentMethod.sync(self)
      end

      def trial_end_date(subscription)
        return unless subscription.state == "trialing"
        Time.zone.parse(subscription.next_payment[:date]).end_of_day
      end

      def processor_subscription(subscription_id, options = {})
        hash = PaddlePay::Subscription::User.list({subscription_id: subscription_id}, options).try(:first)
        OpenStruct.new(hash)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end
    end
  end
end
