module Pay
  module Paddle
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method

      def self.sync(pay_customer:, attributes:)
        attrs = {}

        details = attributes.method_details

        case details.type.downcase
        when "card"
          attrs[:type] = "card"
          attrs[:brand] = details.card.type
          attrs[:last4] = details.card.last4
          attrs[:exp_month] = details.card.expiry_month
          attrs[:exp_year] = details.card.expiry_year
        when "paypal"
          attrs[:type] = "paypal"
        end

        payment_method = pay_customer.default_payment_method || pay_customer.build_default_payment_method
        payment_method.name = :paddle
        payment_method.processor_id = attributes.stored_payment_method_id

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
