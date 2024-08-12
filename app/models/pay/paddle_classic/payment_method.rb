module Pay
  module PaddleClassic
    class PaymentMethod < Pay::PaymentMethod
      # Paddle doesn't provide PaymentMethod IDs, so we have to lookup via the Customer
      def self.sync(pay_customer:, attributes: nil)
        return unless pay_customer.subscription

        payment_method = pay_customer.default_payment_method || pay_customer.build_default_payment_method
        payment_method.processor_id ||= NanoId.generate

        # Lookup payment method from API unless passed in
        attributes ||= payment_method_details_for(subscription_id: pay_customer.subscription.processor_id)

        payment_method.update!(attributes)
        payment_method
      rescue ::Paddle::Error => e
        raise Pay::PaddleClassic::Error, e
      end

      def self.payment_method_details_for(subscription_id:)
        subscription_user = PaddleClassic.client.users.list(subscription_id: subscription_id).data.try(:first)
        payment_information = subscription_user ? subscription_user[:payment_information] : {}

        case payment_information[:payment_method]&.downcase
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

      def make_default!
      end

      def detach
      end
    end
  end
end
