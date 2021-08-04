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

      def charge(amount, options = {})
        subscription = pay_customer.subscription
        return unless subscription.processor_id
        raise Pay::Error, "A charge_name is required to create a one-time charge" if options[:charge_name].nil?
        response = PaddlePay::Subscription::Charge.create(subscription.processor_id, amount.to_f / 100, options[:charge_name], options)
        charge = pay_customer.charges.find_or_initialize_by(processor_id: response[:invoice_id])
        charge.update(
          amount: (response[:amount].to_f * 100).to_i,
          card_type: processor_subscription(subscription.processor_id).payment_information[:payment_method],
          paddle_receipt_url: response[:receipt_url],
          created_at: Time.zone.parse(response[:payment_date])
        )
        charge
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # pass
      end

      def update_payment_method(token)
        sync_payment_method
      end
      alias_method :update_card, :update_payment_method

      def update_email!
        # pass
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

      def invoice!(options = {})
        # pass
      end

      def upcoming_invoice
        # pass
      end

      def sync_payment_method(attributes: nil)
        payment_method = pay_customer.default_payment_method || pay_customer.build_default_payment_method

        # Lookup payment method from API unless passed in
        attributes ||= payment_information(pay_customer.subscription.processor_id)
        payment_method.update!(attributes)

        payment_method
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def payment_information(subscription_id)
        subscription_user = PaddlePay::Subscription::User.list({subscription_id: subscription_id}).try(:first)
        payment_information = subscription_user ? subscription_user[:payment_information] : nil
        return {} if payment_information.nil?

        case payment_information[:payment_method]
        when "card"
          {
            payment_method_type: :card,
            brand: payment_information[:card_type],
            last4: payment_information[:last_four_digits],
            exp_month: payment_information[:expiry_date].split("/").first,
            exp_year: payment_information[:expiry_date].split("/").last
          }
        when "paypal"
          {
            payment_method_type: :paypal,
            brand: "PayPal"
          }
        else
          {}
        end
      end
    end
  end
end
