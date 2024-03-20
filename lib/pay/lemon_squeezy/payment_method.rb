module Pay
  module LemonSqueezy
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method

      def self.sync(pay_customer:, attributes:)
        return unless pay_customer.subscription

        payment_method = pay_customer.default_payment_method || pay_customer.build_default_payment_method
        payment_method.processor_id ||= NanoId.generate

        attrs = {
          type: "card",
          brand: attributes.card_brand,
          last4: attributes.card_last_four
        }

        payment_method.update!(attrs)
        payment_method
      end

      def initialize(pay_payment_method)
        @pay_payment_method = pay_payment_method
      end

      # Sets payment method as default
      def make_default!
      end

      # Remove payment method
      def detach
      end
    end
  end
end
