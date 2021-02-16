module Pay
  module Paddle
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
        # pass
      end

      def charge(amount, options = {})
        subscription = billable.subscription
        return unless subscription.processor_id
        raise Pay::Error, "A charge_name is required to create a one-time charge" if options[:charge_name].nil?
        response = PaddlePay::Subscription::Charge.create(subscription.processor_id, amount.to_f / 100, options[:charge_name], options)
        charge = billable.charges.find_or_initialize_by(processor: :paddle, processor_id: response[:invoice_id])
        charge.update(
          amount: Integer(response[:amount].to_f * 100),
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

      def update_card(token)
        sync_payment_information_from_paddle
      end

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

      def sync_payment_information
        billable.update!(payment_information(billable.subscription.processor_id))
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
            card_type: payment_information[:card_type],
            card_last4: payment_information[:last_four_digits],
            card_exp_month: payment_information[:expiry_date].split("/").first,
            card_exp_year: payment_information[:expiry_date].split("/").last
          }
        when "paypal"
          {
            card_type: "PayPal"
          }
        else
          {}
        end
      end
    end
  end
end
