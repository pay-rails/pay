module Pay
  module LemonSqueezy
    class PaymentMethod < Pay::PaymentMethod
      def self.sync(pay_customer:, attributes:)
        return unless pay_customer.subscription

        payment_method = pay_customer.default_payment_method || pay_customer.build_default_payment_method
        payment_method.processor_id ||= NanoId.generate

        attrs = {
          payment_method_type: "card",
          brand: attributes.card_brand,
          last4: attributes.card_last_four
        }

        payment_method.update!(attrs)
        payment_method
      end

      def make_default!
      end

      def detach
      end
    end
  end
end
